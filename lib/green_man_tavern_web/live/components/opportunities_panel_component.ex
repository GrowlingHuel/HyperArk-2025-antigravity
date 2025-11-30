defmodule GreenManTavernWeb.OpportunitiesPanelComponent do
  use GreenManTavernWeb, :live_component

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:show, fn -> false end)
     |> assign_new(:opportunities, fn -> [] end)}
  end

  @impl true
  def handle_event("close", _params, socket) do
    send(self(), {:close_opportunities_panel})
    {:noreply, socket}
  end

  @impl true
  def handle_event("apply_suggestion", %{"action_data" => _action_data}, socket) do
    # TODO: Implement suggestion application logic
    {:noreply, put_flash(socket, :info, "Feature coming soon!")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <!-- System Opportunities Panel -->
      <div
        id="opportunities-panel"
        class={if(@show, do: "", else: "hidden")}
        style="
          position: fixed;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          width: 500px;
          max-width: 90vw;
          max-height: 600px;
          background: #FFF;
          border: 3px solid #000;
          box-shadow: 4px 4px 0 rgba(0,0,0,0.3);
          z-index: 2000;
          display: flex;
          flex-direction: column;
          font-family: 'Chicago', 'Geneva', monospace;
        "
      >
        <!-- Single integrated header bar -->
        <div style="
          background: #CCCCCC;
          border-bottom: 2px solid #000;
          padding: 8px 12px;
          display: flex;
          justify-content: space-between;
          align-items: center;
          flex-shrink: 0;
        ">
          <h3 style="
            margin: 0;
            padding: 0;
            font-size: 13px;
            font-weight: bold;
            color: #000;
          ">System Opportunities</h3>

          <button
            type="button"
            phx-click="close"
            phx-target={@myself}
            style="
              background: #DDD;
              border: 2px solid #000;
              width: 24px;
              height: 24px;
              padding: 0;
              cursor: pointer;
              font-size: 16px;
              line-height: 1;
              font-weight: bold;
            "
            onmouseover="this.style.background='#BBB'"
            onmouseout="this.style.background='#DDD'"
          >×</button>
        </div>

        <!-- Content area - directly below header, no gap -->
        <div style="
          flex: 1;
          overflow-y: auto;
          padding: 16px;
          background: #FFF;
        ">
          <%= if @opportunities && length(@opportunities) > 0 do %>
            <!-- Opportunities list -->
            <%= for opp <- @opportunities do %>
              <% priority = Map.get(opp, "priority", "low") %>
              <% priority_color = case priority do
                "high" -> "#FF6B6B"
                "medium" -> "#FFA500"
                _ -> "#999"
              end %>
              <div style="
                border: 2px solid #000;
                padding: 12px;
                margin-bottom: 12px;
                background: #F5F5F5;
              ">
                <!-- Priority badge -->
                <div style={"display: inline-block; padding: 2px 8px; font-size: 10px; font-weight: bold; margin-bottom: 8px; background: #{priority_color}; color: #FFF; border: 1px solid #000;"}>
                  <%= String.upcase(priority) %>
                </div>

                <!-- Title -->
                <div style="
                  font-size: 12px;
                  font-weight: bold;
                  margin-bottom: 6px;
                  color: #000;
                "><%= Map.get(opp, "title", "Opportunity") %></div>

                <!-- Description -->
                <div style="
                  font-size: 11px;
                  color: #333;
                  margin-bottom: 10px;
                  line-height: 1.4;
                "><%= Map.get(opp, "description", "") %></div>

                <!-- Apply button -->
                <button
                  type="button"
                  phx-click="apply_suggestion"
                  phx-target={@myself}
                  phx-value-action_data={Jason.encode!(Map.get(opp, "action_data", %{}))}
                  style="
                    background: #FFF;
                    border: 2px solid #000;
                    padding: 6px 12px;
                    font-size: 11px;
                    font-weight: bold;
                    cursor: pointer;
                    font-family: 'Chicago', 'Geneva', monospace;
                  "
                  onmouseover="this.style.background='#EEE'"
                  onmouseout="this.style.background='#FFF'"
                >Apply</button>
              </div>
            <% end %>
          <% else %>
            <!-- Empty state -->
            <div style="
              text-align: center;
              padding: 40px 20px;
              color: #666;
              font-size: 12px;
            ">
              <div style="font-size: 48px; margin-bottom: 16px;">✓</div>
              <div style="font-weight: bold; margin-bottom: 8px;">All Good!</div>
              <div>No opportunities detected. Your system looks well-connected.</div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Backdrop overlay -->
      <div
        class={if(@show, do: "", else: "hidden")}
        phx-click="close"
        phx-target={@myself}
        style="
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          background: rgba(0,0,0,0.5);
          z-index: 1999;
        "
      ></div>

      <style>
        .hidden {
          display: none !important;
        }
      </style>
    </div>
    """
  end
end
