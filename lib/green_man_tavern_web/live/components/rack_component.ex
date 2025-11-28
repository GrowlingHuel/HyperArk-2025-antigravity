defmodule GreenManTavernWeb.RackComponent do
  use GreenManTavernWeb, :live_component

  alias GreenManTavern.Rack

  alias GreenManTavern.Systems
  alias GreenManTavern.Diagrams

  @impl true
  def update(assigns, socket) do
    user_id = assigns.current_user.id

    socket = 
      socket
      |> assign(assigns)
      |> assign_new(:devices, fn -> Rack.list_devices() end)
      |> assign_new(:cables, fn -> Rack.list_patch_cables() end)
      |> assign_new(:projects, fn -> Systems.list_projects() end)
      |> assign_new(:composite_systems, fn -> Diagrams.list_composite_systems(user_id) end)
      |> assign(:patching_state, nil) # nil, {:source, device_id, jack_id}
      |> assign(:editing_device, nil) # nil or %Device{}
      |> assign(:selected_devices, MapSet.new())
      |> assign(:container_width, 800) # Default width, updated by JS hook
      |> assign(:save_system_modal, false) # Modal state

    # Push initial cables to client
    socket = push_event(socket, "update_cables", %{cables: socket.assigns.cables})

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="rack-layout w-full h-full flex bg-[#f0f0f0]">
      <!-- Sidebar -->
      <div class="sidebar w-64 h-full bg-[#e0e0e0] border-r border-[#ccc] flex flex-col overflow-y-auto shrink-0">
        <div class="p-4 border-b border-[#ccc]">
          <h2 class="font-bold text-lg text-[#333]">Library</h2>
        </div>
        
        <!-- My Systems (Composite Systems) -->
        <div class="p-4 border-b border-[#ccc]">
          <h3 class="font-semibold text-sm text-[#666] mb-2 uppercase tracking-wider">My Systems</h3>
          <div class="flex flex-col gap-2">
            <%= for system <- @composite_systems do %>
              <div class="system-item p-2 hover:bg-white/50 rounded cursor-pointer flex items-center gap-2 transition-colors group"
                   phx-click="add_device"
                   phx-value-type="composite"
                   phx-value-id={system.id}
                   phx-target={@myself}>
                <span class="text-lg">📦</span>
                <span class="text-sm text-[#333] group-hover:text-black"><%= system.name %></span>
              </div>
            <% end %>
            <%= if Enum.empty?(@composite_systems) do %>
              <div class="text-xs text-[#999] italic">No saved systems</div>
            <% end %>
          </div>
        </div>

        <!-- Nodes (Projects) -->
        <div class="p-4">
          <h3 class="font-semibold text-sm text-[#666] mb-2 uppercase tracking-wider">Basic Nodes</h3>
          <div class="flex flex-col gap-2">
            <%= for project <- @projects do %>
              <div class="node-item p-2 hover:bg-white/50 rounded cursor-pointer flex items-center gap-2 transition-colors group"
                   phx-click="add_device"
                   phx-value-type="project"
                   phx-value-id={project.id}
                   phx-target={@myself}>
                <span class="text-lg">📄</span>
                <span class="text-sm text-[#333] group-hover:text-black"><%= project.name %></span>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Main Rack Area -->
      <div class="rack-container flex-1 h-full relative overflow-y-auto flex flex-col w-full bg-[#f0f0f0]"
           id="rack-container">
        <!-- Toolbar -->
        <div class="w-full mb-4 flex justify-between items-center">
          <div class="text-sm text-gray-600">
            <%= if MapSet.size(@selected_devices) > 0 do %>
              <%= MapSet.size(@selected_devices) %> devices selected
            <% else %>
              Select devices to create a system
            <% end %>
          </div>
          <%= if MapSet.size(@selected_devices) > 1 do %>
            <button class="px-3 py-1 bg-purple-600 text-white rounded text-sm hover:bg-purple-700 shadow-sm"
                    phx-click="save_as_system"
                    phx-target={@myself}>
              Save as System
            </button>
          <% end %>
        </div>

        <!-- Rack Rails -->
        <div class="rack-frame w-full h-full border-x-8 border-[#ccc] bg-[#fff] relative shadow-2xl overflow-y-auto">
          
          <!-- Cables Layer (SVG) -->
          <!-- Cables Layer (SVG) - Client-side rendered -->
          <svg id="rack-cables-layer" 
               class="cables-layer absolute inset-0 w-full h-full pointer-events-none z-20 overflow-visible"
               phx-hook="RackCables"
               data-cables={Jason.encode!(@cables)}>
            <!-- Paths will be injected by JS -->
          </svg>

          <!-- Devices -->
          <div class="devices-container flex flex-col w-full relative z-10">
            <%= for device <- @devices do %>
              <div class={"device-unit w-full h-24 bg-[#e8e8e8] border-b border-[#ccc] relative flex items-center px-4 shadow-inner group #{if MapSet.member?(@selected_devices, device.id), do: "bg-blue-50 border-blue-200"}"}
                   id={"device-#{device.id}"}>
                
                <!-- Selection Checkbox -->
                <div class="absolute left-2 top-1/2 -translate-y-1/2">
                  <input type="checkbox" 
                         checked={MapSet.member?(@selected_devices, device.id)}
                         phx-click="toggle_selection"
                         phx-value-id={device.id}
                         phx-target={@myself}
                         class="rounded border-gray-400 text-blue-600 focus:ring-blue-500" />
                </div>

                <!-- Device Faceplate -->
                  <div class={"flex items-center gap-4 ml-6"}>
                  <div class={"device-ears w-4 h-16 rounded-sm #{if device.settings["is_composite"], do: "bg-purple-400", else: "bg-[#bbb]"}"}></div>
                  <div>
                    <h3 class="text-[#000] font-mono text-sm tracking-wider uppercase flex items-center gap-2">
                      <%= device.name %>
                      <%= if device.settings["is_composite"] do %>
                        <span class="text-[10px] bg-purple-100 text-purple-800 px-1 rounded border border-purple-200">SYSTEM</span>
                      <% end %>
                      <button class="opacity-0 group-hover:opacity-100 transition-opacity text-xs text-blue-600 hover:text-blue-800"
                              phx-click="edit_device"
                              phx-value-id={device.id}
                              phx-target={@myself}>
                        [Edit]
                      </button>
                    </h3>
                    <div class="text-[#666] text-xs font-mono">ID: <%= String.slice(to_string(device.id), 0, 8) %></div>
                  </div>
                </div>

                <!-- Patch Points (Jacks) - Fixed Position -->
                <!-- 
                   Rack Width: 800px
                   Right Padding: 16px (right-4)
                   Outputs: Rightmost
                   Inputs: Left of Outputs
                   Gap: 32px (gap-8)
                -->
                <!-- Patch Points (Jacks) - Top/Bottom Layout -->
                <div class="ports flex flex-col items-end flex-1">
  <!-- Inputs (Top) -->
   <div class="inputs flex justify-between w-full gap-2">
    <%= for input <- (device.settings["inputs"] || [%{"id" => "in_1", "name" => "IN"}]) do %>
      <div class="flex flex-col items-center group/jack">
        <div class={"jack rack-jack w-6 h-6 rounded-full bg-[#ddd] border-2 cursor-pointer relative z-30 transition-colors #{if is_selected?(@patching_state, device.id, input["id"]), do: "border-[#00f] shadow-[0_0_10px_#00f]", else: "border-[#999] hover:border-[#000]"}"}
          title={input["name"]}
          data-jack-id={"#{device.id}-#{input["id"]}"}
          phx-click="jack_click"
          phx-value-device-id={device.id}
          phx-value-jack-id={input["id"]}
          phx-target={@myself}>
          <div class="absolute inset-0 m-auto w-3 h-3 rounded-full bg-[#333]"></div>
        </div>
        <span class="text-[9px] text-[#666] font-mono mt-1 opacity-0 group-hover/jack:opacity-100 transition-opacity bg-white px-1 rounded border border-gray-200 absolute top-6 z-20 whitespace-nowrap"><%= input["name"] %></span>
      </div>
    <% end %>
  </div>
  <!-- Outputs (Bottom) -->
   <div class="outputs flex justify-between gap-2 mt-2">
    <%= for output <- (device.settings["outputs"] || [%{"id" => "out_1", "name" => "OUT"}]) do %>
      <div class="flex flex-col items-center group/jack">
        <span class="text-[9px] text-[#666] font-mono mb-1 opacity-0 group-hover/jack:opacity-100 transition-opacity bg-white px-1 rounded border border-gray-200 absolute bottom-6 z-20 whitespace-nowrap"><%= output["name"] %></span>
        <div class={"jack rack-jack w-6 h-6 rounded-full bg-[#ddd] border-2 cursor-pointer relative z-30 transition-colors #{if is_selected?(@patching_state, device.id, output["id"]), do: "border-[#00f] shadow-[0_0_10px_#00f]", else: "border-[#999] hover:border-[#000]"}"}
          title={output["name"]}
          data-jack-id={"#{device.id}-#{output["id"]}"}
          phx-click="jack_click"
          phx-value-device-id={device.id}
          phx-value-jack-id={output["id"]}
          phx-target={@myself}>
          <div class="absolute inset-0 m-auto w-3 h-3 rounded-full bg-[#333]"></div>
        </div>
      </div>
    <% end %>
  </div>
</div>

              </div>
            <% end %>
            
          </div>



        </div>
      </div>

      <!-- Edit Device Modal -->
      <%= if @editing_device do %>
        <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-[9999]">
          <div class="bg-white rounded-lg shadow-xl p-6 w-[500px] max-h-[90vh] overflow-y-auto">
            <h2 class="text-xl font-bold mb-4">Edit Device</h2>
            
            <form phx-submit="save_device" phx-target={@myself}>
              <div class="mb-4">
                <label class="block text-sm font-medium text-gray-700">Name</label>
                <input type="text" name="name" value={@editing_device.name} 
                       phx-blur="update_device_name" 
                       phx-value-name={@editing_device.name}
                       phx-target={@myself}
                       class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500" />
              </div>

              <!-- Inputs Config -->
              <div class="mb-4">
                <div class="flex justify-between items-center mb-2">
                  <label class="block text-sm font-medium text-gray-700">Inputs</label>
                  <button type="button" phx-click="add_port" phx-value-type="input" phx-target={@myself} class="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded hover:bg-blue-200">+ Add</button>
                </div>
                <div class="space-y-2">
                  <%= for {input, idx} <- Enum.with_index(@editing_device.settings["inputs"] || []) do %>
                    <div class="flex gap-2">
                      <input type="text" name={"inputs[#{idx}][name]"} value={input["name"]}
                             phx-blur="update_port_name"
                             phx-value-type="input"
                             phx-value-idx={idx}
                             phx-value-name={input["name"]}
                             phx-target={@myself}
                             class="block w-full text-sm rounded-md border-gray-300" />
                      <input type="hidden" name={"inputs[#{idx}][id]"} value={input["id"]} />
                      <button type="button" phx-click="remove_port" phx-value-type="input" phx-value-idx={idx} phx-target={@myself} class="text-red-500 hover:text-red-700">×</button>
                    </div>
                  <% end %>
                </div>
              </div>

              <!-- Outputs Config -->
              <div class="mb-4">
                <div class="flex justify-between items-center mb-2">
                  <label class="block text-sm font-medium text-gray-700">Outputs</label>
                  <button type="button" phx-click="add_port" phx-value-type="output" phx-target={@myself} class="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded hover:bg-blue-200">+ Add</button>
                </div>
                <div class="space-y-2">
                  <%= for {output, idx} <- Enum.with_index(@editing_device.settings["outputs"] || []) do %>
                    <div class="flex gap-2">
                      <input type="text" name={"outputs[#{idx}][name]"} value={output["name"]}
                             phx-blur="update_port_name"
                             phx-value-type="output"
                             phx-value-idx={idx}
                             phx-value-name={output["name"]}
                             phx-target={@myself}
                             class="block w-full text-sm rounded-md border-gray-300" />
                      <input type="hidden" name={"outputs[#{idx}][id]"} value={output["id"]} />
                      <button type="button" phx-click="remove_port" phx-value-type="output" phx-value-idx={idx} phx-target={@myself} class="text-red-500 hover:text-red-700">×</button>
                    </div>
                  <% end %>
                </div>
              </div>

              <div class="flex justify-end gap-2 mt-6">
                <button type="button" phx-click="cancel_edit" phx-target={@myself} class="px-4 py-2 bg-gray-200 text-gray-800 rounded hover:bg-gray-300">Cancel</button>
                <button type="submit" class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700">Save Changes</button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <!-- Save System Modal -->
      <%= if @save_system_modal do %>
        <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div class="bg-white rounded-lg shadow-xl p-6 w-[400px]">
            <h2 class="text-xl font-bold mb-4">Save as System</h2>
            <p class="text-sm text-gray-600 mb-4">
              Create a reusable system from the <%= MapSet.size(@selected_devices) %> selected devices.
            </p>
            
            <form phx-submit="confirm_save_system" phx-target={@myself}>
              <div class="mb-4">
                <label class="block text-sm font-medium text-gray-700">System Name</label>
                <input type="text" name="name" placeholder="e.g. My Custom Filter" required class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-500 focus:ring-purple-500" />
              </div>
              
              <div class="flex justify-end gap-2 mt-6">
                <button type="button" phx-click="cancel_save_system" phx-target={@myself} class="px-4 py-2 bg-gray-200 text-gray-800 rounded hover:bg-gray-300">Cancel</button>
                <button type="submit" class="px-4 py-2 bg-purple-600 text-white rounded hover:bg-purple-700">Save System</button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end



  @impl true
  def handle_event("toggle_selection", %{"id" => id}, socket) do
    selected = socket.assigns.selected_devices
    
    new_selected = 
      if MapSet.member?(selected, id) do
        MapSet.delete(selected, id)
      else
        MapSet.put(selected, id)
      end
      
    {:noreply, assign(socket, :selected_devices, new_selected)}
  end

  @impl true
  def handle_event("save_as_system", _params, socket) do
    {:noreply, assign(socket, :save_system_modal, true)}
  end

  @impl true
  def handle_event("cancel_save_system", _params, socket) do
    {:noreply, assign(socket, :save_system_modal, false)}
  end

  @impl true

  def handle_event("confirm_save_system", %{"system_name" => name}, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected_devices)
    user_id = socket.assigns.current_user.id

    case GreenManTavern.Rack.RackSystemBuilder.build_from_selection(name, selected_ids, user_id) do
      {:ok, _system} ->
        {:noreply,
         socket
         |> assign(:save_system_modal, false)
         |> assign(:selected_devices, MapSet.new())
         |> put_flash(:info, "System '#{name}' saved to library successfully.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save system.")}
    end
  end

  @impl true
  def handle_event("add_device", %{"type" => "composite", "id" => system_id}, socket) do
    user_id = socket.assigns.current_user.id
    # TODO: Get current project ID if applicable
    project_id = nil 

    case GreenManTavern.Rack.RackSystemBuilder.instantiate(system_id, user_id, project_id) do
      {:ok, _device} ->
        # Refresh devices
        devices = Rack.list_devices()
        {:noreply, assign(socket, :devices, devices)}
      
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to add system.")}
    end
  end

  @impl true
  def handle_event("add_device", %{"type" => "project", "id" => project_id}, socket) do
    project = Enum.find(socket.assigns.projects, &(&1.id == String.to_integer(project_id)))
    
    if project do
      # Create new device from project
      device_attrs = %{
        name: project.name,
        user_id: socket.assigns.current_user.id,
        project_id: project.id,
        position_index: length(socket.assigns.devices),
        settings: %{
          "inputs" => Map.values(project.inputs || %{}) |> Enum.sort_by(& &1["id"]),
          "outputs" => Map.values(project.outputs || %{}) |> Enum.sort_by(& &1["id"])
        }
      }
      
      case Rack.create_device(device_attrs) do
        {:ok, _device} ->
          # Refresh devices
          devices = Rack.list_devices()
          {:noreply, assign(socket, :devices, devices)}
          
        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to add device")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("edit_device", %{"id" => id}, socket) do
    device = Enum.find(socket.assigns.devices, &(&1.id == id))
    # Ensure settings has defaults
    settings = device.settings || %{}
    settings = Map.put_new(settings, "inputs", [%{"id" => "in_1", "name" => "IN"}])
    settings = Map.put_new(settings, "outputs", [%{"id" => "out_1", "name" => "OUT"}])
    device = Map.put(device, :settings, settings)
    
    {:noreply, assign(socket, :editing_device, device)}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, :editing_device, nil)}
  end

  @impl true
  def handle_event("update_device_name", %{"value" => new_name}, socket) do
    device = socket.assigns.editing_device
    
    # Update the editing device name in state
    updated_device = Map.put(device, :name, new_name)
    
    # Also save to database immediately
    case Rack.update_device(device, %{name: new_name}) do
      {:ok, saved_device} ->
        # Update both editing device and devices list
        updated_devices = 
          socket.assigns.devices
          |> Enum.map(fn d -> if d.id == saved_device.id, do: saved_device, else: d end)
        
        socket = 
          socket
          |> assign(:editing_device, updated_device)
          |> assign(:devices, updated_devices)
          
        {:noreply, socket}
        
      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_port_name", %{"value" => new_name, "type" => type, "idx" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    device = socket.assigns.editing_device
    key = "#{type}s"
    ports = device.settings[key] || []
    
    # Update the port name at the given index
    updated_ports = List.update_at(ports, idx, fn port -> Map.put(port, "name", new_name) end)
    updated_settings = Map.put(device.settings, key, updated_ports)
    updated_device = Map.put(device, :settings, updated_settings)
    
    # Save to database immediately
    case Rack.update_device(device, %{settings: updated_settings}) do
      {:ok, saved_device} ->
        # Update both editing device and devices list
        updated_devices = 
          socket.assigns.devices
          |> Enum.map(fn d -> if d.id == saved_device.id, do: saved_device, else: d end)
        
        socket = 
          socket
          |> assign(:editing_device, updated_device)
          |> assign(:devices, updated_devices)
          
        {:noreply, socket}
        
      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_port", %{"type" => type}, socket) do
    device = socket.assigns.editing_device
    key = "#{type}s" # inputs or outputs
    ports = device.settings[key] || []
    
    new_id = "#{type}_#{length(ports) + 1}_#{System.unique_integer([:positive])}"
    new_port = %{"id" => new_id, "name" => String.upcase(type)}
    
    updated_settings = Map.put(device.settings, key, ports ++ [new_port])
    updated_device = Map.put(device, :settings, updated_settings)
    
    {:noreply, assign(socket, :editing_device, updated_device)}
  end

  @impl true
  def handle_event("remove_port", %{"type" => type, "idx" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    device = socket.assigns.editing_device
    key = "#{type}s"
    ports = device.settings[key] || []
    
    updated_ports = List.delete_at(ports, idx)
    updated_settings = Map.put(device.settings, key, updated_ports)
    updated_device = Map.put(device, :settings, updated_settings)
    
    {:noreply, assign(socket, :editing_device, updated_device)}
  end

  @impl true
  def handle_event("save_device", params, socket) do
    device = socket.assigns.editing_device
    name = params["name"]
    
    # Reconstruct inputs/outputs from form params
    # params looks like: {"name" => "...", "inputs" => %{"0" => %{"name" => "...", "id" => "..."}}, ...}
    
    inputs = 
      (params["inputs"] || %{})
      |> Enum.sort_by(fn {k, _} -> String.to_integer(k) end)
      |> Enum.map(fn {_, v} -> v end)

    outputs = 
      (params["outputs"] || %{})
      |> Enum.sort_by(fn {k, _} -> String.to_integer(k) end)
      |> Enum.map(fn {_, v} -> v end)

    updated_settings = 
      device.settings
      |> Map.put("inputs", inputs)
      |> Map.put("outputs", outputs)

    case Rack.update_device(device, %{name: name, settings: updated_settings}) do
      {:ok, updated_device} ->
        # Update list
        updated_devices = 
          socket.assigns.devices
          |> Enum.map(fn d -> if d.id == updated_device.id, do: updated_device, else: d end)
        
        socket = 
          socket
          |> assign(:devices, updated_devices)
          |> assign(:editing_device, nil)
          |> put_flash(:info, "Device updated successfully")
          
        {:noreply, socket}
        
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update device")}
    end
  end

  @impl true
  def handle_event("jack_click", %{"device-id" => device_id, "jack-id" => jack_id}, socket) do
    case socket.assigns.patching_state do
      nil ->
        # Start patching
        {:noreply, assign(socket, :patching_state, {:source, device_id, jack_id})}

      {:source, source_device_id, source_jack_id} ->
        if source_device_id == device_id and source_jack_id == jack_id do
          # Clicked same jack, cancel
          {:noreply, assign(socket, :patching_state, nil)}
        else
          # Complete connection
          cable_attrs = %{
            user_id: socket.assigns.current_user.id,
            source_device_id: source_device_id,
            source_jack_id: source_jack_id,
            target_device_id: device_id,
            target_jack_id: jack_id,
            cable_color: Enum.random(["#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff00ff"])
          }

          case Rack.create_patch_cable(cable_attrs) do
            {:ok, cable} ->
              socket = 
                socket
                |> update(:cables, fn cables -> cables ++ [cable] end)
                |> assign(:patching_state, nil)
                |> push_event("update_cables", %{cables: socket.assigns.cables ++ [cable]})
              {:noreply, socket}
            
            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Failed to connect cable")}
          end
        end
    end
  end

  defp is_selected?({:source, s_dev, s_jack}, dev_id, jack_id) do
    s_dev == dev_id and s_jack == jack_id
  end
  defp is_selected?(_, _, _), do: false

  @impl true
  def handle_event("delete_cable", %{"id" => cable_id}, socket) do
    case Rack.delete_patch_cable(cable_id) do
      {:ok, _} ->
        cables = Rack.list_patch_cables()
        {:noreply, 
         socket 
         |> assign(:cables, cables)
         |> push_event("update_cables", %{cables: cables})}
         
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete cable.")}
    end
  end
end
