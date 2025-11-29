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

  def instantiate(composite_system_id, user_id, project_id) do
    case Diagrams.get_composite_system!(composite_system_id) do
      nil -> {:error, :not_found}
      system ->
        # Convert map inputs/outputs to list for device settings
        inputs_list = Map.values(system.external_inputs || %{}) |> Enum.sort_by(& &1["id"])
        outputs_list = Map.values(system.external_outputs || %{}) |> Enum.sort_by(& &1["id"])

        device_attrs = %{
          name: system.name,
          user_id: user_id,
          project_id: project_id,
          position_index: 0, # Should be calculated or appended
          settings: %{
            "is_composite" => true,
            "composite_system_id" => system.id,
            "inputs" => inputs_list,
            "outputs" => outputs_list
          }
        }

        Rack.create_device(device_attrs)
    end
  end
end
