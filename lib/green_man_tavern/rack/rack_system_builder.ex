defmodule GreenManTavern.Rack.RackSystemBuilder do
  @moduledoc """
  Logic for collapsing multiple devices into a single Composite Device.
  """

  alias GreenManTavern.Rack
  alias GreenManTavern.Rack.Device
  alias GreenManTavern.Rack.PatchCable

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

    # 4. Create the Composite Device
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
        "internal_cables" => Enum.map(internal_cables, & &1.id)
      }
    }

    {:ok, composite_device} = Rack.create_device(device_attrs)

    # 5. Re-route external cables to the new composite device
    
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

    # 6. Hide/Delete original devices?
    # For now, let's just delete them from the rack view (delete from DB)
    # BUT we need to keep their definitions if we want to "expand" later.
    # Actually, for a true "Composite System", we should probably serialize them into the `settings` 
    # and then delete the rows.
    
    # For this MVP, we will DELETE the original devices.
    # Note: This deletes internal cables too due to cascade delete.
    Enum.each(devices, &Rack.delete_device(&1))

    {:ok, composite_device}
  end
end
