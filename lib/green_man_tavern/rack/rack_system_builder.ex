defmodule GreenManTavern.Rack.RackSystemBuilder do
  @moduledoc """
  Logic for collapsing multiple devices into a single Composite Device.
  """

  alias GreenManTavern.Rack
  alias GreenManTavern.Rack.Device
  alias GreenManTavern.Rack.PatchCable

  alias GreenManTavern.Diagrams

  def create_composite_system(name, device_ids, user_id, project_id) do
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

    # 3. Define inputs/outputs for the new composite device
    # Map external connections to new ports on the composite device
    
    # Inputs: Where an external cable connects TO one of our internal devices
    # We need to expose that internal jack as an input on the composite
    composite_inputs = 
      external_inputs
      |> Enum.with_index()
      |> Enum.map(fn {cable, idx} -> 
        %{
          "id" => "in_#{idx + 1}", 
          "name" => "IN #{idx + 1}",
          "internal_device_id" => cable.target_device_id,
          "internal_jack_id" => cable.target_jack_id
        }
      end)

    # Outputs: Where an internal device connects TO an external device
    composite_outputs = 
      external_outputs
      |> Enum.with_index()
      |> Enum.map(fn {cable, idx} -> 
        %{
          "id" => "out_#{idx + 1}", 
          "name" => "OUT #{idx + 1}",
          "internal_device_id" => cable.source_device_id,
          "internal_jack_id" => cable.source_jack_id
        }
      end)

    # 4. Create the Composite Device (in the Rack)
    device_attrs = %{
      name: name,
      user_id: user_id,
      project_id: project_id,
      position_index: 0, # Should be calculated
      settings: %{
        "is_composite" => true,
        "inputs" => composite_inputs,
        "outputs" => composite_outputs,
        "internal_devices" => Enum.map(devices, & &1.id),
        "internal_cables" => Enum.map(internal_cables, & &1.id),
        "composite_system_id" => nil # Will be updated after system creation
      }
    }

    {:ok, composite_device} = Rack.create_device(device_attrs)

    # 5. Create the Composite System (in the Library)
    # Serialize internal structure
    nodes_data = 
      devices 
      |> Map.new(fn d -> 
        {to_string(d.id), %{
          name: d.name,
          project_id: d.project_id,
          settings: d.settings,
          position_index: d.position_index
        }} 
      end)

    edges_data = 
      internal_cables
      |> Map.new(fn c -> 
        {to_string(c.id), %{
          source_device_id: c.source_device_id,
          source_jack_id: c.source_jack_id,
          target_device_id: c.target_device_id,
          target_jack_id: c.target_jack_id,
          cable_color: c.cable_color
        }} 
      end)

    system_attrs = %{
      name: name,
      description: "Created from Rack selection",
      user_id: user_id,
      internal_node_ids: Enum.map(devices, &to_string(&1.id)),
      internal_edge_ids: Enum.map(internal_cables, &to_string(&1.id)),
      internal_nodes_data: nodes_data,
      internal_edges_data: edges_data,
      external_inputs: Map.new(composite_inputs, &{&1["id"], &1}),
      external_outputs: Map.new(composite_outputs, &{&1["id"], &1})
    }
    
    {:ok, composite_system} = Diagrams.create_composite_system(system_attrs)
    
    # Update composite device to reference the system
    Rack.update_device(composite_device, %{settings: Map.put(composite_device.settings, "composite_system_id", composite_system.id)})


    # 6. Re-route external cables to the new composite device
    
    # Update external inputs (cables coming IN to the system)
    Enum.each(Enum.with_index(external_inputs), fn {cable, idx} ->
      Rack.update_patch_cable(cable, %{
        target_device_id: composite_device.id,
        target_jack_id: "in_#{idx + 1}"
      })
    end)

    # Update external outputs (cables going OUT of the system)
    Enum.each(Enum.with_index(external_outputs), fn {cable, idx} ->
      Rack.update_patch_cable(cable, %{
        source_device_id: composite_device.id,
        source_jack_id: "out_#{idx + 1}"
      })
    end)

    # 7. Delete original devices
    Enum.each(devices, &Rack.delete_device(&1))

    {:ok, composite_device, composite_system}
  end
end
