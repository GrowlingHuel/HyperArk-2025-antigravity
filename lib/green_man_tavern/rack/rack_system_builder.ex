defmodule GreenManTavern.Rack.RackSystemBuilder do
  @moduledoc """
  Logic for creating reusable Composite Systems from a selection of Rack Devices.
  """

  alias GreenManTavern.Rack
  alias GreenManTavern.Diagrams
  alias GreenManTavern.Repo

  def build_from_selection(name, device_ids, user_id) do
    # 1. Fetch all devices and cables
    devices = Rack.list_devices() |> Enum.filter(&(&1.id in device_ids))
    all_cables = Rack.list_patch_cables()
    
    # 2. Identify internal vs external cables
    internal_cables = Enum.filter(all_cables, fn c -> 
      c.source_device_id in device_ids and c.target_device_id in device_ids 
    end)
    
    external_inputs = Enum.filter(all_cables, fn c -> 
      c.target_device_id in device_ids and c.source_device_id not in device_ids 
    end)
    
    external_outputs = Enum.filter(all_cables, fn c -> 
      c.source_device_id in device_ids and c.target_device_id not in device_ids 
    end)

    # 3. Define inputs/outputs for the new composite system
    
    # Inputs: Where an external cable connects TO one of our internal devices
    composite_inputs = 
      external_inputs
      |> Enum.with_index()
      |> Map.new(fn {cable, idx} -> 
        id = "in_#{idx + 1}"
        {id, %{
          "id" => id, 
          "name" => "IN #{idx + 1}",
          "internal_device_id" => cable.target_device_id,
          "internal_jack_id" => cable.target_jack_id
        }}
      end)

    # Outputs: Where an internal device connects TO an external device
    composite_outputs = 
      external_outputs
      |> Enum.with_index()
      |> Map.new(fn {cable, idx} -> 
        id = "out_#{idx + 1}"
        {id, %{
          "id" => id, 
          "name" => "OUT #{idx + 1}",
          "internal_device_id" => cable.source_device_id,
          "internal_jack_id" => cable.source_jack_id
        }}
      end)

    # 4. Serialize Internal Data (exclude unloaded associations)
    internal_nodes_data = Map.new(devices, fn d -> 
      {d.id, d |> Map.from_struct() |> Map.drop([:__meta__, :user, :project, :user_plant, :source_cables, :target_cables])} 
    end)
    
    internal_edges_data = Map.new(internal_cables, fn c -> 
      {c.id, c |> Map.from_struct() |> Map.drop([:__meta__, :user, :source_device, :target_device])} 
    end)

    # 5. Create the Composite System Record
    attrs = %{
      name: name,
      user_id: user_id,
      internal_node_ids: Enum.map(devices, & &1.id),
      internal_edge_ids: Enum.map(internal_cables, & &1.id),
      internal_nodes_data: internal_nodes_data,
      internal_edges_data: internal_edges_data,
      external_inputs: composite_inputs,
      external_outputs: composite_outputs,
      is_public: false
    }

    Diagrams.create_composite_system(attrs)
  end

  def instantiate(composite_system_id, user_id, project_id, parent_device_id \\ nil) do
    case Diagrams.get_composite_system!(composite_system_id) do
      nil -> {:error, :not_found}
      system ->
        # 1. Create the Parent Device (The System Container)
        inputs_list = Map.values(system.external_inputs || %{}) |> Enum.sort_by(& &1["id"])
        outputs_list = Map.values(system.external_outputs || %{}) |> Enum.sort_by(& &1["id"])

        device_attrs = %{
          name: system.name,
          user_id: user_id,
          project_id: project_id,
          parent_device_id: parent_device_id,
          position_index: 0, # Should be calculated or appended
          settings: %{
            "is_composite" => true,
            "composite_system_id" => system.id,
            "inputs" => inputs_list,
            "outputs" => outputs_list
          }
        }

        case Rack.create_device(device_attrs) do
          {:ok, parent_device} ->
            # 2. Recursively Create Child Devices
            id_map = 
              Enum.reduce(system.internal_nodes_data, %{}, fn {old_id, data}, acc ->
                child_attrs = %{
                  name: data["name"],
                  position_index: data["position_index"],
                  settings: data["settings"],
                  user_id: user_id,
                  project_id: project_id,
                  parent_device_id: parent_device.id
                }
                
                # If the child is itself a composite, we might need to recurse here?
                # For now, we just create the device as saved. 
                # If we want deep instantiation of nested systems, we'd need to check if data["settings"]["is_composite"] is true
                # and potentially call instantiate recursively. 
                # However, the saved data should already contain the "flat" internal structure of that system 
                # OR it refers to another system ID.
                # Current design: The saved data is a snapshot of the device.
                
                case Rack.create_device(child_attrs) do
                  {:ok, child} -> Map.put(acc, old_id, child.id)
                  _ -> acc # Skip failed devices? Or error out?
                end
              end)

            # 3. Create Internal Cables (Child <-> Child)
            Enum.each(system.internal_edges_data, fn {_id, cable_data} ->
              source_id = id_map[cable_data["source_device_id"]]
              target_id = id_map[cable_data["target_device_id"]]

              if source_id and target_id do
                Rack.create_patch_cable(%{
                  source_device_id: source_id,
                  target_device_id: target_id,
                  source_jack_id: cable_data["source_jack_id"],
                  target_jack_id: cable_data["target_jack_id"],
                  cable_color: cable_data["cable_color"],
                  user_id: user_id
                })
              end
            end)

            # 4. Create Boundary Cables (Parent <-> Child)
            # Input: Parent(jack_id) -> Child(internal_device_id, internal_jack_id)
            Enum.each(system.external_inputs, fn {_key, input_def} ->
              child_id = id_map[input_def["internal_device_id"]]
              if child_id do
                Rack.create_patch_cable(%{
                  source_device_id: parent_device.id, # Parent is source of signal entering the system
                  source_jack_id: input_def["id"],
                  target_device_id: child_id,
                  target_jack_id: input_def["internal_jack_id"],
                  cable_color: "var(--color-cable-1)", # Default color for internal routing
                  user_id: user_id
                })
              end
            end)

            # Output: Child(internal_device_id, internal_jack_id) -> Parent(jack_id)
            Enum.each(system.external_outputs, fn {_key, output_def} ->
              child_id = id_map[output_def["internal_device_id"]]
              if child_id do
                Rack.create_patch_cable(%{
                  source_device_id: child_id,
                  source_jack_id: output_def["internal_jack_id"],
                  target_device_id: parent_device.id, # Parent is target of signal leaving the system
                  target_jack_id: output_def["id"],
                  cable_color: "var(--color-cable-1)",
                  user_id: user_id
                })
              end
            end)

            {:ok, parent_device}

          error -> error
        end
    end
  end
end
