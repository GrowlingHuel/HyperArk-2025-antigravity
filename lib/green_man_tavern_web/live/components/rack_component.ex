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
      |> assign_new(:container_width, fn -> 1000 end) # We need to preserve container_width if it exists
      |> assign(:patching_state, nil) # nil, {:source, device_id, jack_id}
      |> assign(:editing_device, nil) # nil or %Device{}
      |> assign(:selected_devices, MapSet.new())
      |> assign(:show_system_name_modal, false)
      |> assign(:system_name_input, "") # Added for system name modal

    {:ok, socket}
  end

  @impl true
  def handle_event("resize", %{"width" => width}, socket) do
    {:noreply, assign(socket, :container_width, width)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-full bg-white text-gray-900 font-mono">
      <!-- Sidebar -->
      <div class="w-56 bg-[#eeeeee] flex flex-col border-r-2 border-black shrink-0">
        <div class="p-4 border-b-2 border-black bg-white">
          <h2 class="text-lg font-bold text-black flex items-center gap-2 uppercase tracking-tight">
            <span>🎛️</span> Rack Lib
          </h2>
        </div>
        
        <div class="flex-1 overflow-y-auto p-2 space-y-6">
          <!-- My Systems (Composite) -->
          <div>
            <h3 class="text-xs font-bold text-black uppercase tracking-widest mb-2 px-2 border-b border-black pb-1">My Systems</h3>
            <div class="space-y-1">
              <%= for system <- @composite_systems do %>
                <button class="w-full text-left px-3 py-2 border border-transparent hover:border-black hover:bg-white hover:shadow-[2px_2px_0_0_#000] text-sm flex items-center gap-2 group transition-all"
                        phx-click="add_device"
                        phx-value-type="composite"
                        phx-value-id={system.id}
                        phx-target={@myself}>
                  <span class="text-black">📦</span>
                  <span class="truncate font-bold"><%= system.name %></span>
                  <span class="ml-auto opacity-0 group-hover:opacity-100 text-xs text-black font-bold">+</span>
                </button>
              <% end %>
            </div>
          </div>

          <!-- Basic Nodes (Projects) -->
          <div>
            <h3 class="text-xs font-bold text-black uppercase tracking-widest mb-2 px-2 border-b border-black pb-1">Basic Nodes</h3>
            <div class="space-y-1">
              <%= for project <- @projects do %>
                <button class="w-full text-left px-3 py-2 border border-transparent hover:border-black hover:bg-white hover:shadow-[2px_2px_0_0_#000] text-sm flex items-center gap-2 group transition-all"
                        phx-click="add_device"
                        phx-value-type="project"
                        phx-value-id={project.id}
                        phx-target={@myself}>
                  <span>📄</span>
                  <span class="truncate font-bold"><%= project.name %></span>
                  <span class="ml-auto opacity-0 group-hover:opacity-100 text-xs text-black font-bold">+</span>
                </button>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <!-- Main Rack Area -->
      <div class="flex-1 bg-white overflow-hidden flex flex-col relative">
        
        <!-- Toolbar -->
        <div class="h-12 bg-[#eeeeee] border-b-2 border-black flex items-center px-4 justify-between shrink-0 z-30">
          <div class="flex items-center gap-2">
            <span class="text-black font-bold text-sm uppercase">Rack View</span>
            <span class="text-black text-xs">|</span>
            <span class="text-black text-xs font-bold"><%= length(@devices) %> Devices</span>
          </div>
          
          <div class="flex items-center gap-2">
            <%= if MapSet.size(@selected_devices) > 0 do %>
              <span class="text-xs text-black font-bold mr-2"><%= MapSet.size(@selected_devices) %> selected</span>
              
              <%= if MapSet.size(@selected_devices) > 1 do %>
                <button class="text-xs bg-white border border-black hover:bg-black hover:text-white px-3 py-1.5 shadow-[2px_2px_0_0_#000] flex items-center gap-1 transition-all"
                        phx-click="open_system_name_modal"
                        phx-target={@myself}>
                  <span>💾</span> Save System
                </button>
              <% end %>

              <button class="text-xs bg-white border border-black hover:bg-red-600 hover:text-white px-3 py-1.5 shadow-[2px_2px_0_0_#000] flex items-center gap-1 transition-all"
                      phx-click="delete_selected"
                      phx-target={@myself}>
                <span>🗑️</span> Delete
              </button>
            <% end %>
            
            <div class="flex bg-white border border-black shadow-[2px_2px_0_0_#000]">
              <button class="p-1 hover:bg-black hover:text-white border-r border-black" title="Zoom Out">-</button>
              <button class="p-1 hover:bg-black hover:text-white" title="Zoom In">+</button>
            </div>
          </div>
        </div>

        <!-- Rack Container (Scrollable) -->
        <div class="flex-1 overflow-auto flex p-8 relative bg-[url('/images/grid_pattern.png')] bg-repeat" id="rack-scroll-container">
          
          <!-- Rack Rails -->
          <div class="rack-frame w-full mx-auto h-full relative shrink-0" id="rack-frame" phx-hook="RackResize">
            
            <!-- Devices -->
            <div class="devices-container flex flex-col gap-4 p-4 w-full relative z-10 min-h-full content-start">
              <%= for device <- @devices do %>
                <div class={"device-unit w-full h-24 bg-[#f5f5f5] border-2 border-black shadow-[4px_4px_0_0_#000] relative flex flex-col items-center justify-center group transition-all hover:translate-x-[1px] hover:translate-y-[1px] hover:shadow-[3px_3px_0_0_#000] #{if MapSet.member?(@selected_devices, device.id), do: "ring-2 ring-black ring-offset-2"}"}
                     id={"device-#{device.id}"}>
                  
                  <!-- Selection Checkbox -->
                  <div class="absolute left-2 top-2 z-20">
                    <input type="checkbox" 
                           checked={MapSet.member?(@selected_devices, device.id)}
                           phx-click="toggle_selection"
                           phx-value-id={device.id}
                           phx-target={@myself}
                           class="rounded-none border-2 border-black text-black focus:ring-0 w-4 h-4" />
                  </div>

                  <!-- Device Name -->
                  <div class="absolute top-0 left-0 bg-black text-white text-[10px] px-2 py-0.5 font-bold uppercase tracking-widest z-20">
                    <%= device.name %>
                  </div>

                  <!-- Inputs (Top) -->
                  <div class="absolute top-1 w-full text-center text-[9px] text-gray-500 font-bold uppercase tracking-widest pointer-events-none">INPUTS</div>
                  <div class="inputs absolute top-4 left-0 w-full flex justify-center gap-4 pointer-events-none">
                    <%= for input <- (device.settings["inputs"] || [%{"id" => "in_1", "name" => "IN"}]) do %>
                      <div class="flex flex-col items-center group/jack pointer-events-auto">
                        <span class="text-[9px] text-black font-bold mb-0.5 opacity-0 group-hover/jack:opacity-100 transition-opacity bg-white border border-black px-1 absolute -top-5 z-30 whitespace-nowrap shadow-[2px_2px_0_0_#000]"><%= input["name"] %></span>
                        <div class={"jack w-5 h-5 rounded-full bg-[#cccccc] border-2 border-black cursor-pointer relative transition-colors #{if is_selected?(@patching_state, device.id, input["id"]), do: "bg-black", else: "hover:bg-[#999]"}"}
                             title={input["name"]}
                             phx-click="jack_click"
                             phx-value-device-id={device.id}
                             phx-value-jack-id={input["id"]}
                             phx-target={@myself}>
                          <div class="absolute inset-0 m-auto w-2 h-2 rounded-full bg-black border border-white/20"></div>
                        </div>
                      </div>
                    <% end %>
                  </div>

                  <!-- Outputs (Bottom) -->
                  <div class="absolute bottom-1 w-full text-center text-[9px] text-gray-500 font-bold uppercase tracking-widest pointer-events-none">OUTPUTS</div>
                  <div class="outputs absolute bottom-4 left-0 w-full flex justify-center gap-4 pointer-events-none">
                    <%= for output <- (device.settings["outputs"] || [%{"id" => "out_1", "name" => "OUT"}]) do %>
                      <div class="flex flex-col items-center group/jack pointer-events-auto">
                        <div class={"jack w-5 h-5 rounded-full bg-[#cccccc] border-2 border-black cursor-pointer relative transition-colors #{if is_selected?(@patching_state, device.id, output["id"]), do: "bg-black", else: "hover:bg-[#999]"}"}
                             title={output["name"]}
                             phx-click="jack_click"
                             phx-value-device-id={device.id}
                             phx-value-jack-id={output["id"]}
                             phx-target={@myself}>
                          <div class="absolute inset-0 m-auto w-2 h-2 rounded-full bg-black border border-white/20"></div>
                        </div>
                        <span class="text-[9px] text-black font-bold mt-0.5 opacity-0 group-hover/jack:opacity-100 transition-opacity bg-white border border-black px-1 absolute -bottom-5 z-30 whitespace-nowrap shadow-[2px_2px_0_0_#000]"><%= output["name"] %></span>
                      </div>
                    <% end %>
                  </div>

                </div>
              <% end %>
              
              <!-- Empty Slot Placeholder -->
              <div class="w-full h-24 border-2 border-dashed border-gray-400 flex items-center justify-center text-gray-400 hover:text-black hover:border-black cursor-pointer transition-colors"
                   phx-click="add_device"
                   phx-value-type="project"
                   phx-value-id="1" 
                   phx-target={@myself}>
                <span class="text-2xl font-bold">+</span>
              </div>
            </div>

            <!-- Cables Layer (SVG) -->
            <svg class="cables-layer absolute inset-0 w-full h-full pointer-events-none z-20 overflow-visible">
              <%= for cable <- @cables do %>
                <%
                  {x1, y1} = get_jack_coordinates(cable.source_device_id, cable.source_jack_id, @devices, @container_width)
                  {x2, y2} = get_jack_coordinates(cable.target_device_id, cable.target_jack_id, @devices, @container_width)
                  path = calculate_cable_path(x1, y1, x2, y2)
                %>
                <path d={path}
                      stroke="black"
                      stroke-width="6"
                      fill="none"
                      stroke-linecap="round"
                      class="opacity-40 drop-shadow-[2px_2px_0_rgba(0,0,0,0.2)]" />
                <path d={path}
                      stroke={cable.cable_color || "#ff0000"}
                      stroke-width="4"
                      fill="none"
                      stroke-linecap="round"
                      class="hover:stroke-[6px] cursor-pointer transition-all" />
              <% end %>

              <!-- Render active patching cable -->
              <%= if @patching_state do %>
                <!-- TODO: Render dynamic cable following cursor -->
              <% end %>
            </svg>

          </div>
        </div>
      </div>
      
      <!-- Modals (Edit Device, System Name) -->
      <%= if @editing_device do %>
        <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 backdrop-blur-sm">
          <div class="bg-white border-2 border-black shadow-[8px_8px_0_0_#000] p-6 w-96 max-h-[90vh] overflow-y-auto">
            <h3 class="text-lg font-bold mb-4 uppercase tracking-widest border-b-2 border-black pb-2">Edit Device</h3>
            
            <form phx-submit="save_device" phx-target={@myself}>
              <!-- Form fields with Hypercard styling -->
              <div class="mb-4">
                <label class="block text-sm font-bold text-black uppercase mb-1">Name</label>
                <input type="text" name="name" value={@editing_device.name} class="w-full border-2 border-black rounded-none p-2 focus:ring-0 focus:border-black bg-[#f5f5f5]" />
              </div>

              <div class="mb-4">
                <label class="block text-sm font-bold text-black uppercase mb-1">Icon (Emoji)</label>
                <input type="text" name="icon" value={@editing_device.settings["icon"]} placeholder="e.g. 🎛️" class="w-full border-2 border-black rounded-none p-2 focus:ring-0 focus:border-black bg-[#f5f5f5]" />
              </div>

              <!-- Inputs Config -->
              <div class="mb-4">
                <div class="flex justify-between items-center mb-2">
                  <label class="block text-sm font-bold text-black uppercase">Inputs</label>
                  <button type="button" phx-click="add_port" phx-value-type="input" phx-target={@myself} class="text-xs bg-black text-white px-2 py-1 shadow-[2px_2px_0_0_#000] hover:bg-gray-800">ADD</button>
                </div>
                <div class="space-y-2">
                  <%= for {input, idx} <- Enum.with_index(@editing_device.settings["inputs"] || []) do %>
                    <div class="flex gap-2">
                      <input type="text" name={"inputs[#{idx}][name]"} value={input["name"]} class="block w-full text-sm border-2 border-black rounded-none p-2 focus:ring-0 focus:border-black bg-[#f5f5f5]" placeholder="Port Name" />
                      <select name={"inputs[#{idx}][type]"} class="block w-32 text-sm border-2 border-black rounded-none p-2 focus:ring-0 focus:border-black bg-[#f5f5f5]">
                        <%= for type <- ["generic", "water", "energy", "data", "biomass"] do %>
                          <option value={type} selected={input["type"] == type}><%= String.capitalize(type) %></option>
                        <% end %>
                      </select>
                      <input type="hidden" name={"inputs[#{idx}][id]"} value={input["id"]} />
                      <button type="button" phx-click="remove_port" phx-value-type="input" phx-value-idx={idx} phx-target={@myself} class="text-red-600 hover:text-red-800 font-bold">×</button>
                    </div>
                  <% end %>
                </div>
              </div>

              <!-- Outputs Config -->
              <div class="mb-4">
                <div class="flex justify-between items-center mb-2">
                  <label class="block text-sm font-bold text-black uppercase">Outputs</label>
                  <button type="button" phx-click="add_port" phx-value-type="output" phx-target={@myself} class="text-xs bg-black text-white px-2 py-1 shadow-[2px_2px_0_0_#000] hover:bg-gray-800">ADD</button>
                </div>
                <div class="space-y-2">
                  <%= for {output, idx} <- Enum.with_index(@editing_device.settings["outputs"] || []) do %>
                    <div class="flex gap-2">
                      <input type="text" name={"outputs[#{idx}][name]"} value={output["name"]} class="block w-full text-sm border-2 border-black rounded-none p-2 focus:ring-0 focus:border-black bg-[#f5f5f5]" placeholder="Port Name" />
                      <select name={"outputs[#{idx}][type]"} class="block w-32 text-sm border-2 border-black rounded-none p-2 focus:ring-0 focus:border-black bg-[#f5f5f5]">
                        <%= for type <- ["generic", "water", "energy", "data", "biomass"] do %>
                          <option value={type} selected={output["type"] == type}><%= String.capitalize(type) %></option>
                        <% end %>
                      </select>
                      <input type="hidden" name={"outputs[#{idx}][id]"} value={output["id"]} />
                      <button type="button" phx-click="remove_port" phx-value-type="output" phx-value-idx={idx} phx-target={@myself} class="text-red-600 hover:text-red-800 font-bold">×</button>
                    </div>
                  <% end %>
                </div>
              </div>
              
              <div class="flex justify-end gap-2 mt-6">
                <button type="button" phx-click="cancel_edit" phx-target={@myself} class="px-4 py-2 border-2 border-black text-sm font-bold hover:bg-gray-200">CANCEL</button>
                <button type="submit" class="px-4 py-2 bg-black text-white border-2 border-black text-sm font-bold hover:bg-gray-800">SAVE</button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <%= if @show_system_name_modal do %>
        <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 backdrop-blur-sm">
          <div class="bg-white border-2 border-black shadow-[8px_8px_0_0_#000] p-6 w-96">
            <h3 class="text-lg font-bold mb-4 uppercase tracking-widest border-b-2 border-black pb-2">Save System</h3>
            <form phx-submit="save_composite_system" phx-target={@myself}>
              <div class="mb-4">
                <label class="block text-sm font-bold text-black uppercase mb-1">System Name</label>
                <input type="text" name="system_name" value={@system_name_input} class="w-full border-2 border-black rounded-none p-2 focus:ring-0 focus:border-black bg-[#f5f5f5]" placeholder="My Awesome System" />
              </div>
              <div class="flex justify-end gap-2">
                <button type="button" phx-click="cancel_system_save" phx-target={@myself} class="px-4 py-2 border-2 border-black text-sm font-bold hover:bg-gray-200">CANCEL</button>
                <button type="submit" class="px-4 py-2 bg-black text-white border-2 border-black text-sm font-bold hover:bg-gray-800">SAVE</button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

    </div>
    """
  end

  @impl true
  def handle_event("add_device", %{"type" => type, "id" => id}, socket) do
    user_id = socket.assigns.current_user.id
    
    case type do
      "project" ->
        # Create a new device from a project
        project = Systems.get_project!(id)
        
        device_attrs = %{
          name: project.name,
          user_id: user_id,
          project_id: project.id,
          position_index: length(socket.assigns.devices),
          settings: %{
            "inputs" => [%{"id" => "in_1", "name" => "IN"}],
            "outputs" => [%{"id" => "out_1", "name" => "OUT"}]
          }
        }

        case Rack.create_device(device_attrs) do
          {:ok, device} ->
            {:noreply, update(socket, :devices, fn devices -> devices ++ [device] end)}
          
          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to create device")}
        end

      "composite" ->
        # Create a new device from a composite system
        system = Diagrams.get_composite_system!(id)
        
        # Use the first project ID from the system or a default
        # Ideally, we should have a 'type' field on device, but for now we use project_id
        project_id = 
          case system.device_definitions do
            [first | _] -> first["project_id"]
            _ -> 1 # Fallback
          end

        device_attrs = %{
          name: system.name,
          user_id: user_id,
          project_id: project_id,
          position_index: length(socket.assigns.devices),
          settings: %{
            "is_composite" => true,
            "composite_system_id" => system.id,
            "inputs" => system.external_inputs || [],
            "outputs" => system.external_outputs || []
          }
        }

        case Rack.create_device(device_attrs) do
          {:ok, device} ->
            {:noreply, update(socket, :devices, fn devices -> devices ++ [device] end)}
          
          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to create composite device")}
        end
    end
  end

  @impl true
  def handle_event("edit_device", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    device = Enum.find(socket.assigns.devices, &(&1.id == id))
    {:noreply, assign(socket, :editing_device, device)}
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, :editing_device, nil)}
  end

  @impl true
  def handle_event("add_port", %{"type" => type}, socket) do
    device = socket.assigns.editing_device
    
    updated_settings = 
      Map.update(device.settings, type <> "s", [], fn ports ->
        new_id = "#{type}_#{length(ports) + 1}_#{System.unique_integer([:positive])}"
        ports ++ [%{"id" => new_id, "name" => String.upcase(type)}]
      end)
    
    updated_device = Map.put(device, :settings, updated_settings)
    {:noreply, assign(socket, :editing_device, updated_device)}
  end

  @impl true
  def handle_event("remove_port", %{"type" => type, "idx" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    device = socket.assigns.editing_device
    
    updated_settings = 
      Map.update(device.settings, type <> "s", [], fn ports ->
        List.delete_at(ports, idx)
      end)
    
    updated_device = Map.put(device, :settings, updated_settings)
    {:noreply, assign(socket, :editing_device, updated_device)}
  end

  @impl true
  def handle_event("save_device", params, socket) do
    device = socket.assigns.editing_device
    name = params["name"]
    icon = params["icon"]
    
    # Reconstruct inputs/outputs from form params
    inputs = 
      (params["inputs"] || %{})
      |> Enum.sort_by(fn {k, _} -> String.to_integer(k) end)
      |> Enum.map(fn {_, v} -> 
        # Normalize map keys to strings
        Enum.reduce(v, %{}, fn {key, val}, acc -> Map.put(acc, to_string(key), val) end)
      end)

    outputs = 
      (params["outputs"] || %{})
      |> Enum.sort_by(fn {k, _} -> String.to_integer(k) end)
      |> Enum.map(fn {_, v} -> 
        Enum.reduce(v, %{}, fn {key, val}, acc -> Map.put(acc, to_string(key), val) end)
      end)

    updated_settings = 
      (device.settings || %{})
      |> normalize_settings()
      |> Map.put("inputs", inputs)
      |> Map.put("outputs", outputs)
      |> Map.put("icon", icon)

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
  def handle_event("jack_click", %{"device-id" => device_id_str, "jack-id" => jack_id}, socket) do
    device_id = String.to_integer(device_id_str)

    case socket.assigns.patching_state do
      nil ->
        # Start patching
        {:noreply, assign(socket, :patching_state, {:source, device_id, jack_id})}

      {:source, source_device_id, source_jack_id} ->
        if source_device_id == device_id and source_jack_id == jack_id do
          # Clicked same jack, cancel
          {:noreply, assign(socket, :patching_state, nil)}
        else
          # Validate Ontological Connection
          source_device = Enum.find(socket.assigns.devices, &(&1.id == source_device_id))
          target_device = Enum.find(socket.assigns.devices, &(&1.id == device_id))
          
          source_port = find_port(source_device, source_jack_id)
          target_port = find_port(target_device, jack_id)
          
          source_type = source_port["type"] || "generic"
          target_type = target_port["type"] || "generic"
          
          if source_type == "generic" or target_type == "generic" or source_type == target_type do
            # Complete connection
            cable_attrs = %{
              user_id: socket.assigns.current_user.id,
              source_device_id: source_device_id,
              source_jack_id: source_jack_id,
              target_device_id: device_id,
              target_jack_id: jack_id,
              cable_color: Enum.random(["#ef4444", "#22c55e", "#3b82f6", "#eab308", "#a855f7", "#ec4899", "#14b8a6", "#f97316"])
            }

            case Rack.create_patch_cable(cable_attrs) do
              {:ok, cable} ->
                socket = 
                  socket
                  |> update(:cables, fn cables -> cables ++ [cable] end)
                  |> assign(:patching_state, nil)
                {:noreply, socket}
              
              {:error, _changeset} ->
                {:noreply, put_flash(socket, :error, "Failed to connect cable")}
            end
          else
             {:noreply, put_flash(socket, :error, "Cannot connect #{String.capitalize(source_type)} to #{String.capitalize(target_type)}")}
          end
        end
    end
  end

  defp find_port(device, port_id) do
    ((device.settings["inputs"] || []) ++ (device.settings["outputs"] || []))
    |> Enum.find(&(&1["id"] == port_id))
  end

  @impl true
  def handle_event("toggle_selection", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
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
  def handle_event("open_system_name_modal", _, socket) do
    {:noreply, assign(socket, :show_system_name_modal, true)}
  end

  @impl true
  def handle_event("cancel_system_save", _, socket) do
    {:noreply, assign(socket, :show_system_name_modal, false)}
  end

  @impl true
  def handle_event("save_composite_system", %{"system_name" => name}, socket) do
    user_id = socket.assigns.current_user.id
    selected_ids = MapSet.to_list(socket.assigns.selected_devices)
    
    # Logic to create composite system
    case GreenManTavern.Rack.RackSystemBuilder.create_composite_system(user_id, name, selected_ids) do
      {:ok, _composite_system} ->
        # Refresh lists
        socket = 
          socket
          |> assign(:selected_devices, MapSet.new())
          |> assign(:show_system_name_modal, false)
          |> assign(:composite_systems, Diagrams.list_composite_systems(user_id))
          |> put_flash(:info, "Composite System '#{name}' created!")
          
        {:noreply, socket}
        
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create system: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("delete_selected", _, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected_devices)
    
    # Delete devices
    Enum.each(selected_ids, fn id ->
      device = Rack.get_device!(id)
      Rack.delete_device(device)
    end)
    
    # Refresh list
    {:noreply, 
     socket
     |> assign(:devices, Rack.list_devices())
     |> assign(:selected_devices, MapSet.new())
     |> put_flash(:info, "Deleted #{length(selected_ids)} devices")}
  end

  defp is_selected?({:source, s_dev, s_jack}, dev_id, jack_id) do
    s_dev == dev_id and s_jack == jack_id
  end
  defp is_selected?(_, _, _), do: false

  # Helper to ensure string keys
  defp normalize_settings(settings) do
    Enum.reduce(settings, %{}, fn {k, v}, acc ->
      Map.put(acc, to_string(k), v)
    end)
  end

  defp get_jack_coordinates(device_id, jack_id, devices, container_width) do
    # Find device index
    index = Enum.find_index(devices, fn d -> d.id == device_id end)
    
    if index do
      # Single Column Fluid Calculation
      # Container Width: Dynamic (container_width)
      # Gap: 16px (1rem)
      # Padding: 16px (1rem)
      
      # Available width for column: container_width - 32 (padding)
      col_width = container_width - 32
      row_height = 96 # h-24
      gap = 16
      padding = 16
      
      # Top-left of the device
      dev_x = padding
      dev_y = padding + index * (row_height + gap)
      
      # Jack positions relative to device
      # Inputs: Top (top-4 = 16px, + half jack 10px = 26px)
      # Outputs: Bottom (bottom-4 = 16px, + half jack 10px = 26px from bottom -> 96 - 26 = 70px)
      
      device = Enum.at(devices, index)
      inputs = device.settings["inputs"] || []
      outputs = device.settings["outputs"] || []
      
      input_idx = Enum.find_index(inputs, &(&1["id"] == jack_id))
      output_idx = Enum.find_index(outputs, &(&1["id"] == jack_id))
      
      {rel_x, rel_y} = 
        cond do
          input_idx -> 
            # Inputs at Top
            # Center them. 
            count = length(inputs)
            spacing = 40 # Wider spacing for fluid layout
            total_width = count * spacing
            start_x = (col_width - total_width) / 2 + (spacing / 2)
            {start_x + (input_idx * spacing), 26}
            
          output_idx -> 
            # Outputs at Bottom
            count = length(outputs)
            spacing = 40
            total_width = count * spacing
            start_x = (col_width - total_width) / 2 + (spacing / 2)
            {start_x + (output_idx * spacing), 70}
            
          true -> 
            {col_width / 2, row_height / 2}
        end
      
      {dev_x + rel_x, dev_y + rel_y}
    else
      {0, 0}
    end
  end

  # Calculate path for "guitar lead" style (hanging cable)
  defp calculate_cable_path(x1, y1, x2, y2) do
    # Distance
    dx = x2 - x1
    dy = y2 - y1
    dist = :math.sqrt(dx*dx + dy*dy)
    
    # Slack depends on distance. 
    # For guitar leads, they hang quite a bit.
    # Add a base slack plus distance factor.
    slack = 50 + (dist * 0.25)
    
    # Control points
    # CP1: Below start point
    # CP2: Below end point
    # This creates a "U" shape or catenary-like curve
    
    cp1x = x1 + (dx * 0.05) # Slight horizontal pull
    cp1y = y1 + slack
    
    cp2x = x2 - (dx * 0.05) # Slight horizontal pull
    cp2y = y2 + slack
    
    "M #{x1} #{y1} C #{cp1x} #{cp1y}, #{cp2x} #{cp2y}, #{x2} #{y2}"
  end
end
