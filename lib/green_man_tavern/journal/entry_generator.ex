defmodule GreenManTavern.Journal.EntryGenerator do
  @moduledoc """
  Generates journal entries from conversation history.

  Automatically creates journal entries when users interact with characters,
  capturing both user disclosures and character advice/knowledge.
  """

  alias GreenManTavern.{Journal, Characters, Conversations}

  @doc """
  Generates a journal entry from a conversation history entry.

  This function should be called after a conversation entry is created.
  It will analyze the message and create an appropriate journal entry.
  """
  def generate_from_conversation(conversation_id) when is_integer(conversation_id) do
    require Logger
    Logger.debug("[EntryGenerator] Generating journal entry for conversation #{conversation_id}")

    # Get the conversation entry from database (ensures we have all fields including inserted_at)
    conversation = Conversations.get_conversation_entry_by_id!(conversation_id)
    Logger.debug("[EntryGenerator] Loaded conversation: type=#{conversation.message_type}, inserted_at=#{inspect(conversation.inserted_at)}")

    generate_from_conversation_struct(conversation)
  rescue
    error ->
      require Logger
      Logger.error("[EntryGenerator] Error generating journal entry: #{inspect(error)}")
      Logger.error("[EntryGenerator] Stacktrace: #{inspect(__STACKTRACE__)}")
      {:error, %Ecto.Changeset{errors: [generation: {"Failed to generate journal entry", []}]}}
  end

  def generate_from_conversation_struct(%{message_type: "user"} = conversation) do
    character = Characters.get_character!(conversation.character_id)
    message = conversation.message_content

    # Extract key information from user message
    journal_body = format_user_message(character.name, message)

    # Get the most recent day number and use same day if created recently (within 1 hour), otherwise increment
    max_day = Journal.get_max_day_number(conversation.user_id)

    # Check if there's a recent entry (same day concept)
    # Use conversation timestamp or current time
    conv_time = Map.get(conversation, :inserted_at) || NaiveDateTime.utc_now()
    recent_entry = get_most_recent_entry(conversation.user_id)
    next_day = if recent_entry && within_same_day?(recent_entry.inserted_at, conv_time) do
      recent_entry.day_number
    else
      max_day + 1
    end

    # Create journal entry
    Journal.create_entry(%{
      user_id: conversation.user_id,
      body: journal_body,
      source_type: "character_conversation",
      source_id: conversation.id,
      entry_date: Journal.format_entry_date(next_day),
      day_number: next_day
    })
  end

  def generate_from_conversation_struct(%{message_type: "character"} = conversation) do
    character = Characters.get_character!(conversation.character_id)
    message = conversation.message_content

    # Extract advice/knowledge from character message
    journal_body = format_character_message(character.name, message)

    # Get the most recent day number and use same day if created recently (within 1 hour), otherwise increment
    max_day = Journal.get_max_day_number(conversation.user_id)

    # Check if there's a recent entry (same day concept)
    # Use conversation timestamp or current time
    conv_time = Map.get(conversation, :inserted_at) || NaiveDateTime.utc_now()
    recent_entry = get_most_recent_entry(conversation.user_id)
    next_day = if recent_entry && within_same_day?(recent_entry.inserted_at, conv_time) do
      recent_entry.day_number
    else
      max_day + 1
    end

    # Create journal entry
    Journal.create_entry(%{
      user_id: conversation.user_id,
      body: journal_body,
      source_type: "character_conversation",
      source_id: conversation.id,
      entry_date: Journal.format_entry_date(next_day),
      day_number: next_day
    })
  end

  # Helper to get most recent journal entry
  defp get_most_recent_entry(user_id) do
    alias GreenManTavern.Journal.Entry
    import Ecto.Query
    alias GreenManTavern.Repo

    Entry
    |> where([e], e.user_id == ^user_id)
    |> order_by([e], desc: e.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  # Check if two timestamps are within the same "day" (1 hour window)
  defp within_same_day?(entry_time, conversation_time) when is_nil(entry_time) or is_nil(conversation_time), do: false
  defp within_same_day?(entry_time, conversation_time) do
    # Convert NaiveDateTime to DateTime if needed, then calculate difference
    entry_dt = case entry_time do
      %NaiveDateTime{} = ndt -> DateTime.from_naive!(ndt, "Etc/UTC")
      %DateTime{} = dt -> dt
      _ -> nil
    end

    conv_dt = case conversation_time do
      %NaiveDateTime{} = ndt -> DateTime.from_naive!(ndt, "Etc/UTC")
      %DateTime{} = dt -> dt
      _ -> nil
    end

    case {entry_dt, conv_dt} do
      {nil, _} -> false
      {_, nil} -> false
      {entry_dt, conv_dt} ->
        diff_seconds = DateTime.diff(conv_dt, entry_dt, :second)
        abs(diff_seconds) < 3600 # Within 1 hour
    end
  end

  # Format user messages into journal entries
  defp format_user_message(character_name, message) do
    message_lower = String.downcase(message)

    # Check for common patterns and extract key information
    cond do
      # Living space / constraints information (apartment, small space, etc.)
      Regex.match?(~r/(?:live\s+in|living\s+in|living\s+space|apartment|small\s+space|studio|room)/i, message) ->
        living_space = extract_living_space(message)
        "Told #{character_name} that I live in #{living_space}."

      # Location information (city, area, etc.)
      Regex.match?(~r/(?:i\s+(?:live|am|stay|reside)\s+(?:in|at|near)|location|address)[\s:]*([^.!?]+)/i, message) ->
        location = extract_location(message)
        "Told #{character_name} that I currently live in #{location}."

      # Personal information patterns
      Regex.match?(~r/i\s+(?:am|have|do|like|prefer|want|need|enjoy)/i, message) ->
        # Extract the key part of the sentence
        key_part = extract_key_phrase(message)
        "Told #{character_name} that #{key_part}."

      # Default: create a more generic entry
      true ->
        # Try to create a concise summary (first 100 chars or first sentence)
        summary = String.slice(message, 0, min(100, String.length(message)))
        summary = if String.length(message) > 100, do: summary <> "...", else: summary
        "Told #{character_name}: \"#{summary}\""
    end
  end

  # Helper to extract living space information
  defp extract_living_space(message) do
    # Try to extract apartment, small space, etc.
    cond do
      Regex.match?(~r/apartment/i, message) ->
        if Regex.match?(~r/small\s+space|very\s+small/i, message) do
          "a very small apartment"
        else
          "an apartment"
        end
      Regex.match?(~r/small\s+space|very\s+small/i, message) ->
        "a very small space"
      Regex.match?(~r/studio/i, message) ->
        "a studio"
      Regex.match?(~r/single\s+room/i, message) ->
        "a single room"
      true ->
        # Fallback: extract the phrase after "live in"
        case Regex.run(~r/live\s+in\s+(.+?)(?:[.,!?]|$)/i, message) do
          [_, space_desc] -> String.trim(space_desc)
          _ -> "a small space"
        end
    end
  end

  # Format character messages into journal entries
  defp format_character_message(character_name, message) do
    message_lower = String.downcase(message)

    # Check for patterns indicating advice, teaching, or knowledge sharing
    cond do
      # Teaching/instruction patterns
      Regex.match?(~r/(?:you\s+can|you\s+should|here'?s\s+how|i'?ll\s+teach|let\s+me\s+(?:show|explain|teach))/i, message) ->
        topic = extract_topic(message)
        "#{character_name} taught me about #{topic}."

      # Advice patterns
      Regex.match?(~r/(?:you\s+should|i\s+(?:recommend|suggest|advise)|try|consider)/i, message) ->
        advice = extract_advice(message)
        "#{character_name} advised: \"#{advice}\""

      # Information sharing patterns
      Regex.match?(~r/(?:did\s+you\s+know|fun\s+fact|interesting|important|note|remember)/i, message) ->
        info = extract_information(message)
        "#{character_name} shared: \"#{info}\""

      # Default: create a summary entry
      true ->
        summary = String.slice(message, 0, min(120, String.length(message)))
        summary = if String.length(message) > 120, do: summary <> "...", else: summary
        "#{character_name} said: \"#{summary}\""
    end
  end

  # Helper functions to extract information

  defp extract_location(message) do
    # Try to extract location from common patterns
    case Regex.run(~r/(?:i\s+(?:live|am|stay|reside)\s+(?:in|at|near)\s*)([A-Z][a-zA-Z\s]+?)(?:[.,!?]|$)/i, message) do
      [_, location] -> String.trim(location)
      _ ->
        # Fallback: try to extract any capitalized place name
        case Regex.run(~r/(?:in|at|near)\s+([A-Z][a-zA-Z\s]+?)(?:[.,!?]|$)/, message) do
          [_, location] -> String.trim(location)
          _ -> "an undisclosed location"
        end
    end
  end

  defp extract_key_phrase(message) do
    # Extract the main clause from "I [verb] [rest]"
    case Regex.run(~r/i\s+(am|have|do|like|prefer|want|need|enjoy|can|will)\s+(.+?)(?:[.,!?]|$)/i, message) do
      [_, verb, rest] -> "#{verb} #{String.trim(rest)}"
      _ ->
        # Fallback: first 80 characters
        String.slice(message, 0, 80) |> String.trim()
    end
  end

  defp extract_topic(message) do
    # Extract the topic being taught about
    case Regex.run(~r/(?:how\s+to|about|regarding|concerning)\s+([a-z\s]+?)(?:[.,!?]|$)/i, message) do
      [_, topic] -> String.trim(topic)
      _ ->
        # Try to get first noun phrase
        case Regex.run(~r/([a-z]+(?:\s+[a-z]+){0,3})\s+(?:is|are|can|will|should)/i, message) do
          [_, topic] -> String.trim(topic)
          _ -> "their area of expertise"
        end
    end
  end

  defp extract_advice(message) do
    # Extract the advice given
    case Regex.run(~r/(?:should|try|consider)\s+(.+?)(?:[.,!?]|$)/i, message) do
      [_, advice] ->
        advice = String.trim(advice)
        String.slice(advice, 0, 100)
      _ ->
        # Fallback: first sentence or 100 chars
        String.split(message, ".") |> List.first() |> String.trim() |> String.slice(0, 100)
    end
  end

  defp extract_information(message) do
    # Extract the information being shared
    first_sentence = String.split(message, ".") |> List.first() |> String.trim()
    String.slice(first_sentence, 0, 120)
  end

  defp format_entry_date(day_number) do
    ordinal_suffix = get_ordinal_suffix(day_number)
    "#{day_number}#{ordinal_suffix} Day"
  end

  defp get_ordinal_suffix(n) when rem(n, 10) == 1 and rem(n, 100) != 11, do: "st"
  defp get_ordinal_suffix(n) when rem(n, 10) == 2 and rem(n, 100) != 12, do: "nd"
  defp get_ordinal_suffix(n) when rem(n, 10) == 3 and rem(n, 100) != 13, do: "rd"
  defp get_ordinal_suffix(_n), do: "th"
end
