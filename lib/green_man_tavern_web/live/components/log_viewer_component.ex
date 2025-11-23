defmodule GreenManTavernWeb.LogViewerComponent do
  use GreenManTavernWeb, :live_component
  alias GreenManTavern.Logging.LogStore

  @impl true
  def update(assigns, socket) do
    if connected?(socket) do
      LogStore.subscribe()
    end

    logs = LogStore.get_logs()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:logs, logs)
     |> assign(:filter, "all")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="log-viewer" style="
      position: fixed;
      bottom: 0;
      left: 0;
      right: 0;
      height: 300px;
      background: #222;
      color: #EEE;
      border-top: 2px solid #000;
      z-index: 2000;
      display: flex;
      flex-direction: column;
      font-family: 'Courier New', monospace;
      font-size: 12px;
      box-shadow: 0 -4px 10px rgba(0,0,0,0.3);
    ">
      <div class="log-header" style="
        padding: 8px;
        background: #333;
        border-bottom: 1px solid #444;
        display: flex;
        justify-content: space-between;
        align-items: center;
      ">
        <div style="display: flex; gap: 12px; align-items: center;">
          <span style="font-weight: bold;">System Logs</span>
          <select phx-change="filter_logs" phx-target={@myself} style="background: #444; color: #FFF; border: 1px solid #555; padding: 2px 6px;">
            <option value="all" selected={@filter == "all"}>All Levels</option>
            <option value="info" selected={@filter == "info"}>Info</option>
            <option value="warn" selected={@filter == "warn"}>Warning</option>
            <option value="error" selected={@filter == "error"}>Error</option>
          </select>
          <button phx-click="clear_logs" phx-target={@myself} style="background: #555; border: 1px solid #666; color: #FFF; padding: 2px 8px; cursor: pointer;">Clear</button>
        </div>
        <button phx-click="toggle_logs" style="background: transparent; border: none; color: #AAA; cursor: pointer; font-size: 16px;">×</button>
      </div>

      <div class="log-content" id="log-content" phx-hook="ScrollToBottom" style="flex: 1; overflow-y: auto; padding: 8px;">
        <%= for log <- Enum.reverse(@logs) do %>
          <%= if should_show?(log, @filter) do %>
            <div class={"log-entry log-#{log.level}"} style={"margin-bottom: 4px; border-bottom: 1px solid #333; padding-bottom: 2px; color: #{color_for_level(log.level)}"}>
              <span style="color: #777;">[<%= Calendar.strftime(log.timestamp, "%H:%M:%S") %>]</span>
              <span style="font-weight: bold; text-transform: uppercase; width: 50px; display: inline-block;"><%= log.level %></span>
              <span><%= log.message %></span>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("filter_logs", %{"value" => filter}, socket) do
    {:noreply, assign(socket, :filter, filter)}
  end

  @impl true
  def handle_event("clear_logs", _, socket) do
    LogStore.clear_logs()
    {:noreply, assign(socket, :logs, [])}
  end

  @impl true
  def handle_info({:new_log, log}, socket) do
    {:noreply, update(socket, :logs, fn logs -> [log | logs] |> Enum.take(100) end)}
  end

  @impl true
  def handle_info(:logs_cleared, socket) do
    {:noreply, assign(socket, :logs, [])}
  end

  defp color_for_level(:error), do: "#FF5555"
  defp color_for_level(:warn), do: "#FFAA00"
  defp color_for_level(:info), do: "#AAAAAA"
  defp color_for_level(_), do: "#AAAAAA"

  defp should_show?(_, "all"), do: true
  defp should_show?(%{level: level}, filter), do: to_string(level) == filter
end
