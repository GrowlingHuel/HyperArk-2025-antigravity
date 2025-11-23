defmodule GreenManTavern.Logging.LogStore do
  use GenServer

  @max_logs 100
  @name __MODULE__

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def add_log(level, message, metadata) do
    GenServer.cast(@name, {:add_log, level, message, metadata})
  end

  def get_logs do
    GenServer.call(@name, :get_logs)
  end

  def clear_logs do
    GenServer.cast(@name, :clear_logs)
  end

  def subscribe do
    Phoenix.PubSub.subscribe(GreenManTavern.PubSub, "browser_logs")
  end

  # Server Callbacks

  @impl true
  def init(_) do
    {:ok, []}
  end

  @impl true
  def handle_cast({:add_log, level, message, metadata}, state) do
    timestamp = DateTime.utc_now()
    log_entry = %{
      id: System.unique_integer([:positive, :monotonic]),
      timestamp: timestamp,
      level: level,
      message: message,
      metadata: metadata
    }

    new_state = [log_entry | state] |> Enum.take(@max_logs)

    # Broadcast the new log entry
    Phoenix.PubSub.broadcast(
      GreenManTavern.PubSub,
      "browser_logs",
      {:new_log, log_entry}
    )

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:clear_logs, _state) do
    Phoenix.PubSub.broadcast(
      GreenManTavern.PubSub,
      "browser_logs",
      :logs_cleared
    )
    {:noreply, []}
  end

  @impl true
  def handle_call(:get_logs, _from, state) do
    {:reply, state, state}
  end
end
