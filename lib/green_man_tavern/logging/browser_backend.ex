defmodule GreenManTavern.Logging.BrowserBackend do
  @behaviour :gen_event

  def init(__opts) do
    {:ok, %{level: :info}}
  end

  def handle_call({:configure, opts}, state) do
    {:ok, :ok, configure(state, opts)}
  end

  def handle_event({level, _gl, {Logger, msg, ts, md}}, state) do
    if meet_level?(level, state.level) do
      log_message(level, msg, ts, md)
    end
    {:ok, state}
  end

  def handle_event(:flush, state) do
    {:ok, state}
  end

  def handle_info(_, state) do
    {:ok, state}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  # Helpers

  defp configure(state, opts) do
    level = Keyword.get(opts, :level, state.level)
    %{state | level: level}
  end

  defp meet_level?(lvl, min) do
    Logger.compare_levels(lvl, min) != :lt
  end

  defp log_message(level, msg, _ts, md) do
    # Format the message if it's a list or charlist
    formatted_msg =
      case msg do
        val when is_binary(val) -> val
        val when is_list(val) -> to_string(val)
        _ -> inspect(msg)
      end

    # Forward to LogStore asynchronously to avoid blocking the logger
    GreenManTavern.Logging.LogStore.add_log(level, formatted_msg, md)
  end
end
