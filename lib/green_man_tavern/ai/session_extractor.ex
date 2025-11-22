defmodule GreenManTavern.AI.SessionExtractor do
  @moduledoc """
  Compiles conversation session data at session-end.

  This module processes a complete conversation session and organizes
  all extracted data into a structured format. It does NOT make API calls -
  it only compiles data that was already extracted during the session.

  ## Usage

      iex> SessionExtractor.extract_session_data("550e8400-e29b-41d4-a716-446655440000")
      {:ok, %{
        session_metadata: %{...},
        facts_extracted: [...],
        questions_asked: [...],
        advice_given: [...],
        emotional_tones: [...],
        commitment_signals: [...],
        conversation_messages: [...]
      }}
  """

  require Logger
  alias GreenManTavern.Sessions

  @doc """
  Extracts and compiles all session data for a given session_id.

  This function:
  1. Loads all messages from the session
  2. Loads all enhanced extraction data that was stored during the session
  3. Compiles into a structured format

  Returns `{:ok, compiled_data}` or `{:error, reason}`.

  ## Examples

      iex> extract_session_data("550e8400-e29b-41d4-a716-446655440000")
      {:ok, %{
        session_metadata: %{
          character_id: 1,
          user_id: 2,
          duration_minutes: 15,
          message_count: 10
        },
        facts_extracted: [...],
        questions_asked: [...],
        advice_given: [...],
        emotional_tones: [...],
        commitment_signals: [...],
        conversation_messages: [...]
      }}

      iex> extract_session_data("nonexistent-session")
      {:error, :session_not_found}
  """
  def extract_session_data(session_id) when is_binary(session_id) do
    try do
      # Load all messages from the session
      messages = Sessions.get_session_messages(session_id)

      if messages == [] do
        {:error, :session_not_found}
      else
        # Get session metadata
        metadata = Sessions.get_session_metadata(session_id)

        if metadata == nil do
          {:error, :session_not_found}
        else
          # Compile extraction data from messages
          compiled_data = compile_session_data(messages, metadata)

          {:ok, compiled_data}
        end
      end
    rescue
      error ->
        Logger.error("Session extraction error: #{inspect(error)}")
        {:error, error}
    end
  end

  defp compile_session_data(messages, metadata) do
    # Extract all data from messages
    {facts, questions, advice, tones, commitments, conversation_messages} =
      Enum.reduce(messages, {[], [], [], [], [], []}, fn message, acc ->
        extract_from_message(message, acc)
      end)

    # Calculate duration in minutes
    duration_minutes =
      if metadata.duration do
        div(metadata.duration, 60)
      else
        0
      end

    %{
      session_metadata: %{
        character_id: metadata.character_id,
        user_id: metadata.user_id,
        duration_minutes: duration_minutes,
        message_count: metadata.message_count
      },
      facts_extracted: Enum.reverse(facts),
      questions_asked: Enum.reverse(questions) |> Enum.filter(&(&1 != nil and &1 != "")),
      advice_given: Enum.reverse(advice) |> Enum.filter(&(&1 != nil and &1 != "")),
      emotional_tones: Enum.reverse(tones) |> Enum.filter(&(&1 != nil)),
      commitment_signals: Enum.reverse(commitments) |> Enum.filter(&(&1 != nil)),
      conversation_messages: Enum.reverse(conversation_messages)
    }
  end

  defp extract_from_message(message, {facts_acc, questions_acc, advice_acc, tones_acc, commitments_acc, messages_acc}) do
    # Extract from extracted_facts field if it exists and contains enhanced extraction data
    extraction_data = extract_from_stored_data(message.extracted_facts)

    # Collect facts
    new_facts =
      case extraction_data do
        %{facts: facts} when is_list(facts) -> facts
        _ -> []
      end

    # Collect questions (only from user messages)
    new_question =
      if message.message_type == "user" do
        case extraction_data do
          %{user_question: question} when is_binary(question) and question != "" -> question
          _ -> nil
        end
      else
        nil
      end

    # Collect advice (only from character messages)
    new_advice =
      if message.message_type == "character" do
        case extraction_data do
          %{character_advice: advice} when is_binary(advice) and advice != "" -> advice
          _ -> nil
        end
      else
        nil
      end

    # Collect emotional tone (only from user messages)
    new_tone =
      if message.message_type == "user" do
        case extraction_data do
          %{emotional_tone: tone} when is_binary(tone) and tone != "" -> tone
          _ -> nil
        end
      else
        nil
      end

    # Collect commitment level (only from user messages)
    new_commitment =
      if message.message_type == "user" do
        case extraction_data do
          %{commitment_level: level} when is_binary(level) and level != "" -> level
          _ -> nil
        end
      else
        nil
      end

    # Collect full message content for context
    message_entry = %{
      type: message.message_type,
      content: message.message_content || "",
      timestamp: message.inserted_at
    }

    {
      new_facts ++ facts_acc,
      [new_question | questions_acc],
      [new_advice | advice_acc],
      [new_tone | tones_acc],
      [new_commitment | commitments_acc],
      [message_entry | messages_acc]
    }
  end

  defp extract_from_stored_data(nil), do: %{}
  defp extract_from_stored_data(%{} = data) when is_map(data) do
    # Handle different storage formats
    cond do
      # Format 1: Direct map with all fields
      Map.has_key?(data, "facts") or Map.has_key?(data, :facts) ->
        %{
          facts: normalize_facts(Map.get(data, "facts") || Map.get(data, :facts) || []),
          user_question: normalize_string(Map.get(data, "user_question") || Map.get(data, :user_question)),
          character_advice: normalize_string(Map.get(data, "character_advice") || Map.get(data, :character_advice)),
          emotional_tone: normalize_string(Map.get(data, "emotional_tone") || Map.get(data, :emotional_tone)),
          commitment_level: normalize_string(Map.get(data, "commitment_level") || Map.get(data, :commitment_level))
        }

      # Format 2: Just facts array (backward compatibility)
      is_list(data) ->
        %{facts: normalize_facts(data)}

      # Format 3: Unknown format, try to extract what we can
      true ->
        %{
          facts: normalize_facts(Map.get(data, "facts") || Map.get(data, :facts) || []),
          user_question: normalize_string(Map.get(data, "user_question") || Map.get(data, :user_question)),
          character_advice: normalize_string(Map.get(data, "character_advice") || Map.get(data, :character_advice)),
          emotional_tone: normalize_string(Map.get(data, "emotional_tone") || Map.get(data, :emotional_tone)),
          commitment_level: normalize_string(Map.get(data, "commitment_level") || Map.get(data, :commitment_level))
        }
    end
  end
  defp extract_from_stored_data(_), do: %{}

  defp normalize_facts(nil), do: []
  defp normalize_facts(facts) when is_list(facts), do: facts
  defp normalize_facts(_), do: []

  defp normalize_string(nil), do: nil
  defp normalize_string(""), do: nil
  defp normalize_string(str) when is_binary(str) do
    trimmed = String.trim(str)
    if trimmed == "", do: nil, else: trimmed
  end
  defp normalize_string(_), do: nil
end
