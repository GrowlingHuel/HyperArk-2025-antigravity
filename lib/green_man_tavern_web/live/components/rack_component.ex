defmodule GreenManTavernWeb.RackComponent do
  use GreenManTavernWeb, :live_component

  alias GreenManTavern.Rack

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:devices, fn -> Rack.list_devices() end)
     |> assign_new(:cables, fn -> Rack.list_patch_cables() end)
     |> assign(:patching_state, nil)} # nil, {:source, device_id, jack_id}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="rack-container w-full h-full bg-[#f0f0f0] relative overflow-hidden flex flex-col items-center p-4">
      <!-- Rack Rails -->
      <div class="rack-frame w-full max-w-4xl h-full border-x-8 border-[#ccc] bg-[#fff] relative shadow-2xl overflow-y-auto">
        
        <!-- Devices -->
        <div class="devices-container flex flex-col w-full relative z-10">
          <%= for device <- @devices do %>
            <div class="device-unit w-full h-24 bg-[#e8e8e8] border-b border-[#ccc] relative flex items-center justify-between px-4 shadow-inner"
                 id={"device-#{device.id}"}>
              
              <!-- Device Faceplate -->
              <div class="flex items-center gap-4">
                <div class="device-ears w-4 h-16 bg-[#bbb] rounded-sm"></div>
                <div>
                  <h3 class="text-[#000] font-mono text-sm tracking-wider uppercase"><%= device.name %></h3>
                  <div class="text-[#666] text-xs font-mono">ID: <%= String.slice(to_string(device.id), 0, 8) %></div>
                </div>
              </div>

              <!-- Patch Points (Jacks) -->
              <div class="patch-bay flex gap-4">
                <!-- Inputs -->
                <div class="inputs flex gap-2">
                  <div class="jack w-8 h-8 rounded-full bg-[#ddd] border-2 border-[#999] hover:border-[#000] cursor-pointer relative"
                       phx-click="jack_click"
                       phx-value-device-id={device.id}
                       phx-value-jack-id="in_1"
                       phx-target={@myself}>
                    <div class="absolute inset-0 m-auto w-4 h-4 rounded-full bg-[#333]"></div>
                    <span class="absolute -bottom-4 left-1/2 -translate-x-1/2 text-[9px] text-[#666] font-mono">IN</span>
                  </div>
                </div>

                <!-- Outputs -->
                <div class="outputs flex gap-2">
                  <div class="jack w-8 h-8 rounded-full bg-[#ddd] border-2 border-[#999] hover:border-[#000] cursor-pointer relative"
                       phx-click="jack_click"
                       phx-value-device-id={device.id}
                       phx-value-jack-id="out_1"
                       phx-target={@myself}>
                    <div class="absolute inset-0 m-auto w-4 h-4 rounded-full bg-[#333]"></div>
                    <span class="absolute -bottom-4 left-1/2 -translate-x-1/2 text-[9px] text-[#666] font-mono">OUT</span>
                  </div>
                </div>
              </div>

            </div>
          <% end %>
          
          <!-- Empty Slot Placeholder -->
          <div class="empty-slot w-full h-24 border-b border-[#eee] opacity-20 bg-[url('/images/rack_pattern_light.png')]"></div>
        </div>

        <!-- Cables Layer (SVG) -->
        <svg class="cables-layer absolute inset-0 w-full h-full pointer-events-none z-20 overflow-visible">
          <!-- Render existing cables -->
          <%= for cable <- @cables do %>
            <!-- TODO: Calculate coordinates based on device positions -->
          <% end %>

          <!-- Render active patching cable -->
          <%= if @patching_state do %>
            <!-- TODO: Render dynamic cable following cursor -->
          <% end %>
        </svg>

      </div>
    </div>
    """
  end

  @impl true
  def handle_event("jack_click", %{"device-id" => device_id, "jack-id" => jack_id}, socket) do
    # TODO: Implement patching logic
    {:noreply, socket}
  end
end
