defmodule GreenManTavern.AI.SessionProcessor do
  @moduledoc """
  Processes conversation sessions at session-end to generate journal summaries
  and quest structures.

  This module makes ONE API call to OpenRouter that:
  1. Generates a journal summary (2-3 sentences)
  2. Scores the conversation for quest worthiness
  3. If score ≥ 8, generates a quest structure

  ## Usage

      iex> SessionProcessor.process_session("550e8400-e29b-41d4-a716-446655440000")
      {:ok, %{
        journal_summary: "2-3 sentence summary...",
        quest_data: %{...} or nil
      }}
  """

  require Logger
  alias GreenManTavern.AI.{OpenAIClient, SessionExtractor}

  @doc """
  Processes a session to generate journal summary and quest data.

  Returns `{:ok, %{journal_summary: "...", quest_data: nil_or_map}}` or `{:error, reason}`.

  ## Parameters

  - session_id: The conversation session ID
  - user_id: The user's ID (for context)
  - character_name: The name of the character (e.g., "The Grandmother", "The Alchemist")

  ## Examples

      iex> process_session("550e8400-e29b-41d4-a716-446655440000", 1, "The Grandmother")
      {:ok, %{
        journal_summary: "The user discussed composting with The Grandmother...",
        quest_data: %{
          title: "Start Your Compost Bin",
          objective: "...",
          steps: [...],
          required_skills: %{...},
          estimated_time: "2-3 weeks",
          difficulty_estimate: 5,
          xp_rewards: %{...}
        }
      }}

      iex> process_session("nonexistent-session", 1, "The Grandmother")
      {:error, :session_not_found}
  """
  def process_session(session_id, user_id, character_name)
      when is_binary(session_id) and is_integer(user_id) and is_binary(character_name) do
    try do
      # Step 1: Get compiled session data
      case SessionExtractor.extract_session_data(session_id) do
        {:ok, compiled_data} ->
          # Step 2: Build prompt and make API call
          process_compiled_data(compiled_data, character_name)

        {:error, reason} = error ->
          Logger.warning("Session extraction failed: #{inspect(reason)}")
          error
      end
    rescue
      error ->
        Logger.error("Session processing error: #{inspect(error)}")
        {:error, error}
    end
  end

  # Backward compatibility: if called without character_name, try to get it from session metadata
  def process_session(session_id) when is_binary(session_id) do
    alias GreenManTavern.{Sessions, Characters}

    case Sessions.get_session_metadata(session_id) do
      nil ->
        {:error, :session_not_found}

      metadata ->
        try do
          character = Characters.get_character!(metadata.character_id)
          process_session(session_id, metadata.user_id, character.name)
        rescue
          Ecto.NoResultsError ->
            Logger.warning("Character not found for character_id: #{metadata.character_id}")
            process_session(session_id, metadata.user_id, "the character")
        end
    end
  end

  defp process_compiled_data(compiled_data, character_name) do
    prompt = build_processing_prompt(compiled_data)
    system_prompt = build_system_prompt(character_name)
    metadata = compiled_data.session_metadata
    user_id = metadata.user_id
    character_id = metadata.character_id

    case OpenAIClient.chat(prompt, system_prompt) do
      {:ok, json_text} ->
        Logger.info("[SessionProcessor] Raw response: #{String.slice(json_text, 0, 400)}...")
        parse_processing_response(json_text, user_id, character_id)

      {:error, reason} ->
        Logger.warning("Session processing API call failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_system_prompt(character_name) do
    ~s(You are a conversation analyzer for a permaculture-based RPG game. You are summarizing a conversation between the user and #{character_name}. Use #{character_name} by name in your summary, not "the character". Analyze the conversation session data and generate a journal summary and quest structure if appropriate. Output ONLY valid JSON per the instructions.)
  end

  defp build_processing_prompt(compiled_data) do
    metadata = compiled_data.session_metadata

    facts_text = format_facts(compiled_data.facts_extracted)
    questions_text = format_list("Questions Asked", compiled_data.questions_asked)
    advice_text = format_list("Advice Given", compiled_data.advice_given)
    tones_text = format_list("Emotional Tones", compiled_data.emotional_tones)
    commitments_text = format_list("Commitment Signals", compiled_data.commitment_signals)
    conversation_text = format_conversation(compiled_data.conversation_messages)

    """
    Analyze this conversation session and generate a journal summary and quest structure.

    SESSION METADATA:
    - Character ID: #{metadata.character_id}
    - User ID: #{metadata.user_id}
    - Duration: #{metadata.duration_minutes} minutes
    - Message Count: #{metadata.message_count}

    FULL CONVERSATION:
    #{conversation_text}

    #{facts_text}

    #{questions_text}

    #{advice_text}

    #{tones_text}

    #{commitments_text}

    TASK:
    1. Generate a 2-3 sentence journal summary of this conversation session. IMPORTANT: The summary must accurately reflect what was discussed. Always refer to the character by their actual name (e.g., "The Grandmother", "The Alchemist") rather than generic terms like "the character". If the character provided extensive advice, gardening tips, or guidance, the summary MUST mention this. Do not say "no advice was provided" if the character gave detailed responses. Do NOT start the summary with phrases like "In this conversation" or "During this conversation" - start directly with the content.
    2. Score this conversation for quest worthiness using this algorithm:
       - Multiple questions on same topic: +2 each
       - Specific details requested: +3 each
       - Resource/constraint inquiries: +2 each
       - Comparative questions: +3 each
       - Deduct for: future-framing (-5), theoretical only (-3)
    3. If quest_score ≥ 8, generate a quest structure.

    Respond with ONLY valid JSON in this format:
    {
      "journal_summary": "2-3 sentence summary of the conversation",
      "quest_score": integer (0-15),
      "generate_quest": boolean,
      "quest_data": {
        "title": "character-themed quest title",
        "objective": "clear, actionable objective",
        "steps": ["step 1", "step 2", "step 3"],
        "required_skills": {"domain": difficulty_1_to_10, ...},
        "estimated_time": "time estimate (e.g., '2-3 weeks', '1 month')",
        "difficulty_estimate": integer (1-10),
        "xp_rewards": {"domain": xp_amount, ...}
      }
    }

    If generate_quest is false, quest_data can be null or an empty object.
    Skill domains: "planting", "composting", "system_building", "water_management", "waste_cycling", "connection_making", "maintenance"
    """
  end

  defp format_facts([]), do: "FACTS EXTRACTED:\n(none)"
  defp format_facts(facts) do
    facts_text =
      facts
      |> Enum.map(fn fact ->
        type = Map.get(fact, "type", "unknown")
        key = Map.get(fact, "key", "unknown")
        value = Map.get(fact, "value", "")
        confidence = Map.get(fact, "confidence", 0.0)
        "- [#{type}/#{key}] #{value} (confidence: #{confidence})"
      end)
      |> Enum.join("\n")

    "FACTS EXTRACTED:\n#{facts_text}"
  end

  defp format_list(label, []), do: "#{label}:\n(none)"
  defp format_list(label, items) do
    items_text = items |> Enum.map(&"- #{&1}") |> Enum.join("\n")
    "#{label}:\n#{items_text}"
  end

  defp format_conversation([]), do: "(no messages)"
  defp format_conversation(messages) do
    messages
    |> Enum.map(fn msg ->
      type_label = if msg.type == "user", do: "USER", else: "CHARACTER"
      content = String.slice(msg.content || "", 0, 2000) # Limit length to avoid token bloat
      "#{type_label}: #{content}"
    end)
    |> Enum.join("\n\n")
  end

  defp parse_processing_response(json_text, user_id, character_id) do
    with {:ok, data} <- Jason.decode(json_text) do
      journal_summary = normalize_string(Map.get(data, "journal_summary"))
      # Remove "In this conversation, " prefix if present
      journal_summary = if journal_summary do
        journal_summary
        |> String.trim_leading("In this conversation, ")
        |> String.trim_leading("in this conversation, ")
        |> String.trim()
      else
        journal_summary
      end
      quest_score = Map.get(data, "quest_score", 0)
      generate_quest = Map.get(data, "generate_quest", false)

      quest_data =
        if generate_quest and quest_score >= 8 do
          parse_quest_data(Map.get(data, "quest_data", %{}))
        else
          nil
        end

      # If quest was generated, check for duplicates
      if quest_data do
        alias GreenManTavern.Quests.Deduplication

        case Deduplication.check_for_duplicate(user_id, quest_data) do
          {:duplicate, existing_quest_id} ->
            Logger.info("[SessionProcessor] 🔄 Found duplicate quest, merging instead of creating")

            # Merge perspectives instead of creating new quest
            case Deduplication.merge_quest_perspectives(
              existing_quest_id,
              quest_data,
              character_id
            ) do
              {:ok, updated_quest} ->
                Logger.info("[SessionProcessor] ✅ Merged quest: #{updated_quest.title}")
                # Return existing quest as the result
                {:ok, %{journal_summary: journal_summary || "No summary generated.", quest_data: nil, merged_quest_id: existing_quest_id}}

              {:error, reason} ->
                Logger.warning("[SessionProcessor] Failed to merge: #{inspect(reason)}")
                # Fall back to creating new quest
                {:ok, %{journal_summary: journal_summary || "No summary generated.", quest_data: quest_data}}
            end

          {:unique} ->
            Logger.info("[SessionProcessor] ✅ Quest is unique, will create new")
            {:ok, %{journal_summary: journal_summary || "No summary generated.", quest_data: quest_data}}
        end
      else
        {:ok, %{journal_summary: journal_summary || "No summary generated.", quest_data: nil}}
      end
    else
      error ->
        # Try to extract JSON if wrapped or with extra text
        case extract_json_object(json_text) do
          {:ok, obj} -> parse_processing_response(obj, user_id, character_id)
          _ ->
            Logger.warning("[SessionProcessor] Failed to parse JSON: #{inspect(error)}")
            {:error, :invalid_json_response}
        end
    end
  end

  defp parse_quest_data(nil), do: nil
  defp parse_quest_data(%{} = quest_data) do
    %{
      title: normalize_string(Map.get(quest_data, "title")),
      objective: normalize_string(Map.get(quest_data, "objective")),
      steps: normalize_list(Map.get(quest_data, "steps", [])),
      required_skills: normalize_map(Map.get(quest_data, "required_skills", %{})),
      estimated_time: normalize_string(Map.get(quest_data, "estimated_time")),
      difficulty_estimate: normalize_integer(Map.get(quest_data, "difficulty_estimate")),
      xp_rewards: normalize_map(Map.get(quest_data, "xp_rewards", %{}))
    }
  end
  defp parse_quest_data(_), do: nil

  defp normalize_string(nil), do: nil
  defp normalize_string(""), do: nil
  defp normalize_string(str) when is_binary(str) do
    trimmed = String.trim(str)
    if trimmed == "", do: nil, else: trimmed
  end
  defp normalize_string(_), do: nil

  defp normalize_list(nil), do: []
  defp normalize_list(list) when is_list(list) do
    list
    |> Enum.map(&normalize_string/1)
    |> Enum.filter(&(&1 != nil))
  end
  defp normalize_list(_), do: []

  defp normalize_map(nil), do: %{}
  defp normalize_map(%{} = map) do
    map
    |> Enum.map(fn {k, v} -> {to_string(k), normalize_value(v)} end)
    |> Enum.into(%{})
  end
  defp normalize_map(_), do: %{}

  defp normalize_value(v) when is_binary(v), do: v
  defp normalize_value(v) when is_integer(v), do: v
  defp normalize_value(v) when is_float(v), do: v
  defp normalize_value(_), do: nil

  defp normalize_integer(nil), do: nil
  defp normalize_integer(i) when is_integer(i), do: i
  defp normalize_integer(f) when is_float(f), do: trunc(f)
  defp normalize_integer(str) when is_binary(str) do
    case Integer.parse(str) do
      {i, _} -> i
      _ -> nil
    end
  end
  defp normalize_integer(_), do: nil

  defp extract_json_object(text) do
    # Try to extract JSON object first
    case Regex.run(~r/\{[\s\S]*\}/, text) do
      [json] -> {:ok, json}
      _ -> :error
    end
  end
end
