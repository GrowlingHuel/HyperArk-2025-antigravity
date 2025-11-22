defmodule GreenManTavern.AI.FactExtractor do
  @moduledoc """
  Extracts compact, factual user details from freeform messages and merges them
  into persistent user profile memories.

  Facts schema (stored in user.profile_data["facts"]):
  %{
    "type" => string,
    "key" => string,
    "value" => string,
    "confidence" => float,
    "source" => string,
    "learned_at" => ISO8601 timestamp,
    "context" => optional string
  }
  """

  require Logger
  alias GreenManTavern.AI.OpenAIClient

  @extraction_instructions ~S"""
  Extract conversation elements from the user message and character response.

  Respond with a JSON object containing:
  {
    "facts": [array of facts],
    "user_question": "string or null",
    "character_advice": "string or null",
    "emotional_tone": "string or null",
    "commitment_level": "string or null"
  }

  FACTS: Extract ALL factual information that should be remembered.
  Be AGGRESSIVE: extract multiple facts from compound phrases.
  Do not include opinions or open-ended questions, but include implied facts.

  Confidence scale:
  - 0.60–0.70 = implied or partially certain (user hinted)
  - 0.80–0.90 = stated clearly
  - 1.00 = emphasized or repeated

  Each fact has:
  - type: category (location/planting/climate/resource/constraint/goal/sunlight/water/soil/etc)
  - key: specific aspect (e.g., "city", "plant_type", "container_type", "container_material")
  - value: the extracted value (string)
  - confidence: 0.0–1.0
  - context: (optional) detail if needed

  USER_QUESTION: Extract the main question from user message if present. Return null if no clear question.
  Examples: "How do I start composting?" → "How do I start composting?"
            "I want to plant tomatoes" → null

  CHARACTER_ADVICE: Extract the key actionable advice from character response if present. Return null if no advice.
  Examples: "You should start with a small bin" → "Start with a small bin"
            "That's interesting" → null

  EMOTIONAL_TONE: User's emotional tone. One of: "curious", "anxious", "excited", "uncertain", "confident", or null.
  - curious: asking questions, exploring
  - anxious: worried, concerned, hesitant
  - excited: enthusiastic, eager
  - uncertain: unsure, indecisive
  - confident: certain, decisive

  COMMITMENT_LEVEL: User's commitment to action. One of: "exploring", "considering", "planning", "committing", or null.
  - exploring: just learning, no commitment
  - considering: thinking about it
  - planning: actively planning to do it
  - committing: definite commitment to act

  If no concrete facts to extract, return empty array for facts: []
  """

  @doc """
  Extracts facts and conversation elements from user_message and character_response using OpenAI.

  Returns {:ok, map} with:
  - facts: list of fact maps
  - user_question: string or nil
  - character_advice: string or nil
  - emotional_tone: string or nil
  - commitment_level: string or nil

  Returns {:error, reason} on failure.
  """
  def extract_facts(user_message, character_name, character_response \\ nil)
      when is_binary(user_message) do
    system_prompt = ~s(You are a conversation analyzer. Output ONLY valid JSON per the instructions.)

    character_context = if character_response do
      "\n\nCharacter response: \"#{character_response}\""
    else
      ""
    end

    prompt = """
    #{@extraction_instructions}

    User said: "#{user_message}"#{character_context}
    """

    case OpenAIClient.chat(prompt, system_prompt) do
      {:ok, json_text} ->
        Logger.info("[Facts] Raw response: #{String.slice(inspect(json_text), 0, 400)}...")
        parse_enhanced_json(json_text, character_name)

      {:error, reason} ->
        Logger.warning("Fact extraction failed: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error ->
      Logger.warning("Fact extraction exception: #{inspect(error)}")
      {:error, error}
  end

  defp parse_enhanced_json(json_text, character_name) do
    learned_at = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    with {:ok, data} <- Jason.decode(json_text) do
      # Handle both old format (array) and new format (object)
      result = cond do
        # New format: object with facts and other fields
        is_map(data) and Map.has_key?(data, "facts") ->
          facts = parse_facts_list(Map.get(data, "facts", []), character_name, learned_at)
          # Enforce minimum confidence 0.6
          {kept, filtered} = Enum.split_with(facts, fn f -> (f["confidence"] || 0.0) >= 0.6 end)
          if filtered != [] do
            Logger.info("[Facts] Filtered #{length(filtered)} low-confidence facts (<0.6)")
          end

          {:ok, %{
            facts: kept,
            user_question: normalize_string(Map.get(data, "user_question")),
            character_advice: normalize_string(Map.get(data, "character_advice")),
            emotional_tone: normalize_string(Map.get(data, "emotional_tone")),
            commitment_level: normalize_string(Map.get(data, "commitment_level"))
          }}

        # Old format: just an array of facts (backward compatibility)
        is_list(data) ->
          facts = parse_facts_list(data, character_name, learned_at)
          {kept, filtered} = Enum.split_with(facts, fn f -> (f["confidence"] || 0.0) >= 0.6 end)
          if filtered != [] do
            Logger.info("[Facts] Filtered #{length(filtered)} low-confidence facts (<0.6)")
          end

          {:ok, %{
            facts: kept,
            user_question: nil,
            character_advice: nil,
            emotional_tone: nil,
            commitment_level: nil
          }}

        # Unknown format
        true ->
          Logger.warning("[Facts] Unexpected JSON format: #{inspect(data)}")
          {:ok, %{
            facts: [],
            user_question: nil,
            character_advice: nil,
            emotional_tone: nil,
            commitment_level: nil
          }}
      end

      total = length(result |> elem(1) |> Map.get(:facts))
      Logger.info("[Facts] Parsed=#{total}, Kept=#{length(result |> elem(1) |> Map.get(:facts))}")
      result
    else
      error ->
        # Try to salvage JSON if wrapped or with extra text
        case extract_json_object(json_text) do
          {:ok, obj} -> parse_enhanced_json(obj, character_name)
          _ ->
            Logger.warning("[Facts] Failed to parse JSON: #{inspect(error)}")
            {:ok, %{
              facts: [],
              user_question: nil,
              character_advice: nil,
              emotional_tone: nil,
              commitment_level: nil
            }}
        end
    end
  end

  defp parse_facts_list(facts_data, character_name, learned_at) do
    facts_data
    |> List.wrap()
    |> Enum.filter(&is_map/1)
    |> Enum.map(fn fact ->
      %{
        "type" => Map.get(fact, "type", "unknown"),
        "key" => Map.get(fact, "key", "unknown"),
        "value" => to_string(Map.get(fact, "value", "")),
        "confidence" => fact |> Map.get("confidence", 0.0) |> to_float_safe(),
        "source" => character_name,
        "learned_at" => learned_at,
        "context" => Map.get(fact, "context")
      }
    end)
    |> Enum.filter(fn f -> String.trim(f["value"]) != "" end)
  end

  defp normalize_string(nil), do: nil
  defp normalize_string(""), do: nil
  defp normalize_string(str) when is_binary(str) do
    trimmed = String.trim(str)
    if trimmed == "", do: nil, else: trimmed
  end
  defp normalize_string(_), do: nil

  defp to_float_safe(v) when is_float(v), do: v
  defp to_float_safe(v) when is_integer(v), do: v / 1.0
  defp to_float_safe(v) when is_binary(v) do
    case Float.parse(v) do
      {f, _} -> f
      _ -> 0.0
    end
  end
  defp to_float_safe(_), do: 0.0

  defp extract_json_object(text) do
    # Try to extract JSON object first
    case Regex.run(~r/\{[\s\S]*\}/, text) do
      [json] -> {:ok, json}
      _ ->
        # Fallback to array format
        case Regex.run(~r/\[[\s\S]*\]/, text) do
          [json] -> {:ok, json}
          _ -> :error
        end
    end
  end

  @doc """
  Merge by appending and removing duplicates based on {type,key,value}.
  Sort by learned_at desc.
  """
  def merge_facts(existing_facts, new_facts) do
    all = List.wrap(existing_facts) ++ List.wrap(new_facts)
    all
    |> Enum.uniq_by(fn f -> {Map.get(f, "type"), Map.get(f, "key"), Map.get(f, "value")} end)
    |> Enum.sort_by(fn f -> Map.get(f, "learned_at", "") end, :desc)
  end
end
