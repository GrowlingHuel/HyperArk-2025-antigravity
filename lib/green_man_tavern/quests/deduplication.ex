defmodule GreenManTavern.Quests.Deduplication do
  @moduledoc """
  AI-based quest deduplication module.

  Prevents duplicate quests from being created by comparing proposed quests
  with existing user quests using AI-powered semantic comparison.
  """

  require Logger
  import Ecto.Query
  alias GreenManTavern.{Repo, Quests}
  alias GreenManTavern.Quests.UserQuest
  alias GreenManTavern.AI.{OpenAIClient, EmbeddingGenerator}

  # Similarity threshold for cosine distance (0.20 = 80% similarity)
  # pgvector <=> operator returns cosine distance: 0 = identical, 1 = orthogonal, 2 = opposite
  # Lowered from 0.15 to catch more semantically similar quests with different wording
  @similarity_threshold 0.20

  @doc """
  Checks if a proposed quest is a duplicate of any existing user quests.

  ## Parameters
  - user_id: The user's ID
  - proposed_quest_data: Map with quest data from SessionProcessor (title, objective, required_skills, etc.)

  ## Returns
  - {:duplicate, existing_quest_id} if a duplicate is found
  - {:unique} if no duplicates found

  ## Examples

      iex> check_for_duplicate(1, %{title: "Start Composting", objective: "Build a compost bin"})
      {:unique}

      iex> check_for_duplicate(1, %{title: "Compost Setup", objective: "Create a compost system"})
      {:duplicate, 5}
  """
  def check_for_duplicate(user_id, proposed_quest_data) when is_integer(user_id) and is_map(proposed_quest_data) do
    require Logger

    proposed_title = Map.get(proposed_quest_data, "title") || Map.get(proposed_quest_data, :title) || "Untitled"
    Logger.info("[Dedup] 🔍 Checking for duplicate quests (user: #{user_id}, proposed: '#{proposed_title}')")

    # Get quest text for embedding generation (combines title + objective + description)
    quest_text = extract_quest_text_for_embedding(proposed_quest_data)
    Logger.info("[Dedup] 📝 Using quest text for embedding: #{String.slice(quest_text, 0, 100)}...")

    # Generate embedding for proposed quest
    case EmbeddingGenerator.generate_embedding(quest_text) do
      {:ok, embedding} ->
        Logger.info("[Dedup] ✅ Generated embedding for proposed quest")
        find_similar_quest_by_embedding(user_id, embedding, proposed_title, quest_text)

      {:error, reason} ->
        Logger.warning("[Dedup] ⚠️ Failed to generate embedding: #{inspect(reason)}")
        Logger.info("[Dedup] 🔄 Falling back to AI-based comparison")
        # Fallback to AI-based comparison if embedding generation fails
        check_for_duplicate_ai_fallback(user_id, proposed_quest_data)
    end
  rescue
    error ->
      Logger.error("[Dedup] ❌ Error checking for duplicates: #{inspect(error)}")
      Logger.error("[Dedup] Stacktrace: #{inspect(__STACKTRACE__)}")
      # On error, assume unique to avoid blocking quest creation
      {:unique}
  end

  # Find similar quest using pgvector similarity search
  defp find_similar_quest_by_embedding(user_id, embedding, _proposed_title, proposed_text) do
    require Logger

    # Convert embedding list to PostgreSQL array format for vector casting
    # Format: [0.1,0.2,0.3,...] which PostgreSQL can cast to vector
    embedding_array_str = "[" <> Enum.join(Enum.map(embedding, &Float.to_string/1), ",") <> "]"

    # Query using pgvector <=> operator to find closest match
    # Cosine distance: 0 = identical, 1 = orthogonal, 2 = opposite
    # We want distance < 0.20 (meaning >80% similarity)
    sql = """
    SELECT id, title, objective, description, (description_embedding <=> $1::vector) AS distance
    FROM user_quests
    WHERE user_id = $2
      AND status IN ('available', 'active')
      AND (quest_type != 'planting_window' OR quest_type IS NULL)
      AND description_embedding IS NOT NULL
    ORDER BY distance
    LIMIT 1
    """

    case Repo.query(sql, [embedding_array_str, user_id]) do
      {:ok, %Postgrex.Result{rows: [[quest_id, existing_title, existing_objective, existing_description, distance] | _]}} ->
        existing_text = [existing_title || "", existing_objective || "", existing_description || ""]
          |> Enum.filter(fn t -> t != "" end)
          |> Enum.join(" ")
        Logger.info("[Dedup] 📊 Found closest match: quest_id=#{quest_id}, title='#{existing_title}', distance=#{Float.round(distance, 4)}")

        if distance < @similarity_threshold do
          Logger.info("[Dedup] 🎯 DUPLICATE FOUND: Merging into quest #{quest_id} (distance: #{Float.round(distance, 4)} < #{@similarity_threshold})")
          {:duplicate, quest_id}
        else
          # Additional keyword check for similar topics (e.g., both contain "bokashi")
          if has_matching_keywords?(proposed_text, existing_text) do
            Logger.info("[Dedup] 🔑 Keyword match detected, treating as duplicate")
            {:duplicate, quest_id}
          else
            Logger.info("[Dedup] ✅ UNIQUE: Closest match distance (#{Float.round(distance, 4)}) exceeds threshold (#{@similarity_threshold})")
            {:unique}
          end
        end

      {:ok, %Postgrex.Result{rows: []}} ->
        Logger.info("[Dedup] ✅ UNIQUE: No existing quests with embeddings found")
        {:unique}

      {:error, reason} ->
        Logger.error("[Dedup] ❌ Database query error: #{inspect(reason)}")
        # Fallback to AI comparison on database error
        {:unique}
    end
  end

  # Fallback to AI-based comparison when embedding generation fails
  defp check_for_duplicate_ai_fallback(user_id, proposed_quest_data) do
    require Logger

    proposed_title = Map.get(proposed_quest_data, "title") || Map.get(proposed_quest_data, :title) || "Untitled"
    proposed_text = extract_quest_text_for_embedding(proposed_quest_data)

    # Get all active/available quests for user
    # IMPORTANT: Exclude planting_window quests (they're date-specific)
    existing_quests = from(q in UserQuest,
      where: q.user_id == ^user_id,
      where: q.status in ["available", "active"],
      where: q.quest_type != "planting_window" or is_nil(q.quest_type),
      select: q
    )
    |> Repo.all()

    Logger.info("[Dedup] 📋 Found #{length(existing_quests)} existing quests to compare (AI fallback)")

    # Check each existing quest
    result = Enum.reduce_while(existing_quests, {:unique}, fn existing_quest, _acc ->
      existing_title = existing_quest.title || "Untitled"
      Logger.info("[Dedup] 📊 Comparing: '#{proposed_title}' vs '#{existing_title}' (quest #{existing_quest.id})")

      # First check for keyword matches (faster)
      existing_text = extract_quest_text_for_embedding(existing_quest)
      if has_matching_keywords?(proposed_text, existing_text) do
        Logger.info("[Dedup] 🔑 Keyword match detected, treating as duplicate")
        {:halt, {:duplicate, existing_quest.id}}
      else
        case compare_quests_ai(proposed_quest_data, existing_quest) do
          {:duplicate, confidence} when confidence >= 0.7 ->
            Logger.info("[Dedup] 🎯 DUPLICATE FOUND: Merging into quest #{existing_quest.id} (confidence: #{Float.round(confidence, 2)})")
            {:halt, {:duplicate, existing_quest.id}}

          _ ->
            Logger.debug("[Dedup] ✓ Quest #{existing_quest.id} is unique, continuing...")
            {:cont, {:unique}}
        end
      end
    end)

    case result do
      {:duplicate, quest_id} ->
        Logger.info("[Dedup] 🎯 DUPLICATE FOUND: Merging into quest #{quest_id}")
        result
      {:unique} ->
        Logger.info("[Dedup] ✅ UNIQUE: Will create new quest")
        result
    end
  end

  @doc """
  Compares two quests using AI to determine if they are duplicates.

  ## Parameters
  - proposed_quest: Map with quest data (title, objective, required_skills)
  - existing_quest: UserQuest struct or map with quest data

  ## Returns
  - {:duplicate, confidence} where confidence is 0.0-1.0
  - {:unique, nil}

  ## Examples

      iex> compare_quests_ai(%{title: "Compost", objective: "Build bin"}, %UserQuest{title: "Composting", objective: "Create compost"})
      {:duplicate, 0.85}
  """
  def compare_quests_ai(proposed_quest, existing_quest) do
    require Logger

    proposed_title = Map.get(proposed_quest, "title") || Map.get(proposed_quest, :title) || "Untitled"
    existing_title = existing_quest.title || "Untitled"
    Logger.info("[Dedup] 🤖 Starting AI comparison: '#{proposed_title}' vs '#{existing_title}'")

    prompt = build_comparison_prompt(proposed_quest, existing_quest)

    system_prompt = """
    You are a quest deduplication analyzer. Compare two quests and determine if they are duplicates.

    Consider duplicates if:
    - Same core objective (even with different wording)
    - Same topic/subject matter
    - Similar required skills
    - Would teach the same thing

    NOT duplicates if:
    - Different specific implementation (e.g., "Build bokashi bin" vs "Build worm bin")
    - Different dates (planting quests)
    - Different plants/varieties
    - Clearly different scope

    Output ONLY valid JSON:
    {
      "is_duplicate": true/false,
      "confidence": 0.0-1.0,
      "reason": "Brief explanation"
    }
    """

    case OpenAIClient.chat(prompt, system_prompt) do
      {:ok, json_text} ->
        try do
          result = Jason.decode!(json_text)

          if result["is_duplicate"] && result["confidence"] >= 0.7 do
            Logger.info("[Dedup] 🎯 Duplicate detected (#{result["confidence"]}): #{result["reason"]}")
            {:duplicate, result["confidence"]}
          else
            Logger.info("[Dedup] ✅ Quests are unique (#{result["confidence"]})")
            {:unique}
          end
        rescue
          error ->
            Logger.error("[Dedup] Failed to parse AI response: #{inspect(error)}")
            {:unique}  # Default to unique on error
        end

      {:error, reason} ->
        Logger.error("[Dedup] AI call failed: #{inspect(reason)}")
        {:unique}  # Default to unique on error
    end
  rescue
    error ->
      Logger.error("[Dedup] ❌ Error in AI comparison: #{inspect(error)}")
      {:unique}  # Default to unique on error
  end

  @doc """
  Merges a new quest perspective into an existing quest.

  When a duplicate is found, this function merges the new quest data with the existing quest,
  adding character-specific information and combining skill requirements.

  ## Parameters
  - existing_quest_id: The ID of the existing UserQuest
  - new_quest_data: Map with new quest data from SessionProcessor
  - character_id: ID of the character who suggested the new quest

  ## Returns
  - {:ok, updated_quest} on success
  - {:error, changeset} on failure

  ## Examples

      iex> merge_quest_perspectives(5, %{"title" => "Compost", "required_skills" => %{"composting" => 3}}, 1)
      {:ok, %UserQuest{}}
  """
  def merge_quest_perspectives(existing_quest_id, new_quest_data, character_id) when is_integer(existing_quest_id) and is_integer(character_id) do
    require Logger
    alias GreenManTavern.Characters

    Logger.info("[Dedup] 🔀 Merging quest perspectives: existing_quest_id=#{existing_quest_id}, character_id=#{character_id}")

    quest = Repo.get!(UserQuest, existing_quest_id)
    new_title = Map.get(new_quest_data, "title") || Map.get(new_quest_data, :title) || "Untitled"
    Logger.info("[Dedup] 📝 Merging new quest '#{new_title}' into existing quest '#{quest.title || "Untitled"}' (ID: #{quest.id})")

    # Add character to suggested_by array using SQL UPDATE with array_append
    # This prevents double-adding the character_id (SQL condition ensures it's only added if not already present)
    sql = """
    UPDATE user_quests
    SET suggested_by_character_ids = array_append(suggested_by_character_ids, $1)
    WHERE id = $2
      AND NOT ($1 = ANY(suggested_by_character_ids))
    RETURNING suggested_by_character_ids
    """

    # Execute SQL UPDATE and handle result
    _updated_character_ids = case Repo.query(sql, [character_id, existing_quest_id]) do
      {:ok, %Postgrex.Result{rows: [[updated_ids] | _]}} ->
        Logger.info("[Dedup] ➕ Added character #{character_id} to suggesters list via SQL UPDATE")
        Logger.info("[Dedup] 🔄 Merged quest now suggested by #{length(updated_ids)} characters")
        updated_ids

      {:ok, %Postgrex.Result{rows: []}} ->
        # No rows updated means character_id was already in the array
        Logger.info("[Dedup] ℹ️ Character #{character_id} already in suggesters list, no update needed")
        quest.suggested_by_character_ids || []

      {:error, reason} ->
        Logger.error("[Dedup] ❌ SQL UPDATE failed: #{inspect(reason)}")
        # Fallback to Elixir list operations on SQL error
        existing_ids = quest.suggested_by_character_ids || []
        if character_id in existing_ids do
          Logger.info("[Dedup] ℹ️ Character #{character_id} already in suggesters list (fallback)")
          existing_ids
        else
          Logger.info("[Dedup] ➕ Adding character #{character_id} to suggesters list (fallback)")
          existing_ids ++ [character_id]
        end
    end

    # Reload quest to get updated suggested_by_character_ids
    quest = Repo.get!(UserQuest, existing_quest_id)
    updated_character_ids = quest.suggested_by_character_ids || []

    # Merge skill requirements (take highest level for each skill)
    existing_skills = quest.required_skills || %{}
    new_skills = Map.get(new_quest_data, "required_skills") || Map.get(new_quest_data, :required_skills) || %{}
    merged_skills = merge_skill_requirements(existing_skills, new_skills)

    if map_size(new_skills) > 0 do
      Logger.info("[Dedup] 🎓 Merged skill requirements: #{inspect(existing_skills)} + #{inspect(new_skills)} = #{inspect(merged_skills)}")
    end

    # Sum XP rewards
    existing_xp = quest.xp_rewards || %{}
    new_xp = Map.get(new_quest_data, "xp_rewards") || Map.get(new_quest_data, :xp_rewards) || %{}
    merged_xp = merge_xp_rewards(existing_xp, new_xp)

    if map_size(new_xp) > 0 do
      Logger.info("[Dedup] 💎 Increased XP rewards: #{inspect(existing_xp)} + #{inspect(new_xp)} = #{inspect(merged_xp)}")
    end

    # Extract and store key points from new quest
    character = Characters.get_character!(character_id)
    new_description = Map.get(new_quest_data, "description") || Map.get(new_quest_data, :description) || ""
    new_objective = Map.get(new_quest_data, "objective") || Map.get(new_quest_data, :objective) || ""
    key_points = extract_key_points(new_description, new_objective)

    # Update conversation_key_points
    # Handle both list and map defaults (Ecto uses %{} but we store as list)
    existing_key_points = case quest.conversation_key_points do
      nil -> []
      [] -> []
      %{} -> []  # Empty map default from Ecto schema
      list when is_list(list) -> list
      _ -> []  # Fallback for any other format
    end
    updated_key_points = add_character_key_points(existing_key_points, character.name, key_points)

    # Add character perspective to description
    updated_description = add_character_perspective(
      quest.description || quest.objective || "",
      character.name,
      key_points
    )

    Logger.info("[Dedup] 📄 Updated description with perspective from #{character.name}")
    Logger.info("[Dedup] 📝 Stored #{length(key_points)} key points from #{character.name}")

    # Update quest
    case quest
    |> UserQuest.changeset(%{
      suggested_by_character_ids: updated_character_ids,
      required_skills: merged_skills,
      xp_rewards: merged_xp,
      description: updated_description,
      conversation_key_points: updated_key_points
    })
    |> Repo.update() do
      {:ok, updated_quest} ->
        Logger.info("[Dedup] ✅ Successfully merged quest perspectives: quest_id=#{updated_quest.id}, suggesters=#{length(updated_character_ids)}")
        {:ok, updated_quest}

      {:error, changeset} ->
        Logger.error("[Dedup] ❌ Failed to merge quest perspectives: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  rescue
    error ->
      Logger.error("[Dedup] ❌ Error merging quest perspectives: #{inspect(error)}")
      Logger.error("[Dedup] Stacktrace: #{inspect(__STACKTRACE__)}")
      {:error, error}
  end

  @doc """
  Builds the AI prompt for comparing two quests.

  ## Parameters
  - proposed_quest: Map with quest data
  - existing_quest: UserQuest struct or map

  ## Returns
  - String prompt for AI

  ## Examples

      iex> build_comparison_prompt(%{title: "Compost"}, %UserQuest{title: "Composting"})
      "Are these two quests duplicates? Quest 1: ..."
  """
  def build_comparison_prompt(proposed, existing) do
    existing_title = existing.title || "Untitled"
    existing_objective = existing.objective || existing.description || "No objective"
    existing_skills = existing.required_skills || %{}

    proposed_title = Map.get(proposed, "title") || Map.get(proposed, :title) || "Untitled"
    proposed_objective = Map.get(proposed, "objective") || Map.get(proposed, :objective) || Map.get(proposed, "description") || Map.get(proposed, :description) || "No objective"
    proposed_skills = Map.get(proposed, "required_skills") || Map.get(proposed, :required_skills) || %{}

    """
    Compare these two quests:

    QUEST 1 (Existing):
    Title: #{existing_title}
    Objective: #{existing_objective}
    Skills: #{inspect(existing_skills)}

    QUEST 2 (Proposed):
    Title: #{proposed_title}
    Objective: #{proposed_objective}
    Skills: #{inspect(proposed_skills)}

    Are these duplicate quests that should be merged?
    """
  end

  # Private helper functions

  defp get_comparable_quests(user_id) do
    from(uq in UserQuest,
      where: uq.user_id == ^user_id,
      where: uq.status in ["available", "active"],
      where: is_nil(uq.quest_id),  # Only dynamic quests (AI-generated)
      order_by: [desc: uq.inserted_at]
    )
    |> Repo.all()
  end

  defp build_system_prompt do
    ~s(You are a quest deduplication analyzer for a permaculture-based RPG game. Your job is to determine if two quests are duplicates. Output ONLY valid JSON per the instructions. Be strict - only mark as duplicates if the quests are essentially the same task with the same objectives.)
  end

  defp parse_comparison_response(json_text) do
    case Jason.decode(json_text) do
      {:ok, data} ->
        is_duplicate = Map.get(data, "is_duplicate", false)
        confidence = parse_confidence(Map.get(data, "confidence", 0.0))
        reasoning = Map.get(data, "reasoning", "")

        Logger.info("[Deduplication] 📊 AI analysis: is_duplicate=#{is_duplicate}, confidence=#{confidence}, reasoning=#{String.slice(reasoning, 0, 100)}...")

        if is_duplicate && confidence >= 0.7 do
          {:duplicate, confidence}
        else
          {:unique, nil}
        end

      {:error, reason} ->
        Logger.warning("[Deduplication] ⚠️ Failed to parse AI response: #{inspect(reason)}")
        # Try to extract JSON if wrapped
        case extract_json_object(json_text) do
          {:ok, json} -> parse_comparison_response(json)
          _ -> {:unique, nil}
        end
    end
  end

  defp parse_confidence(value) when is_float(value), do: value
  defp parse_confidence(value) when is_integer(value), do: value / 1.0
  defp parse_confidence(value) when is_binary(value) do
    case Float.parse(value) do
      {f, _} -> f
      _ -> 0.0
    end
  end
  defp parse_confidence(_), do: 0.0

  defp extract_json_object(text) do
    case Regex.run(~r/\{[\s\S]*\}/, text) do
      [json] -> {:ok, json}
      _ -> :error
    end
  end

  defp get_quest_title(quest) when is_map(quest) do
    cond do
      Map.has_key?(quest, :title) && quest.title -> quest.title
      Map.has_key?(quest, "title") && quest["title"] -> quest["title"]
      quest.quest && quest.quest.title -> quest.quest.title
      true -> "Untitled"
    end
  end

  defp get_quest_objective(quest) when is_map(quest) do
    cond do
      Map.has_key?(quest, :objective) && quest.objective -> quest.objective
      Map.has_key?(quest, "objective") && quest["objective"] -> quest["objective"]
      Map.has_key?(quest, :description) && quest.description -> quest.description
      Map.has_key?(quest, "description") && quest["description"] -> quest["description"]
      quest.quest && quest.quest.description -> quest.quest.description
      true -> "No objective"
    end
  end

  defp get_quest_skills(quest) when is_map(quest) do
    cond do
      Map.has_key?(quest, :required_skills) && quest.required_skills -> quest.required_skills
      Map.has_key?(quest, "required_skills") && quest["required_skills"] -> quest["required_skills"]
      true -> %{}
    end
  end

  defp format_skills(skills) when is_map(skills) do
    if map_size(skills) == 0 do
      "None"
    else
      skills
      |> Enum.map(fn {domain, level} -> "#{domain} (level #{level})" end)
      |> Enum.join(", ")
    end
  end
  defp format_skills(_), do: "None"

  defp merge_skill_requirements(existing, new) do
    Map.merge(existing, new, fn _skill, level1, level2 ->
      max(level1, level2)
    end)
  end

  defp merge_xp_rewards(existing, new) do
    Map.merge(existing, new, fn _skill, xp1, xp2 ->
      xp1 + xp2
    end)
  end

  defp add_character_perspective(existing_desc, character_name, key_points) when is_list(key_points) do
    if length(key_points) > 0 do
      key_points_text = Enum.join(key_points, ", ")
      existing_desc <> "\n\n#{character_name} also suggests: #{key_points_text}"
    else
      existing_desc
    end
  end

  defp add_character_perspective(existing_desc, character_name, new_perspective) when is_binary(new_perspective) do
    # Fallback for old format (string)
    if new_perspective != "" do
      key_point = extract_key_point(new_perspective)
      existing_desc <> "\n\n#{character_name} also emphasizes: #{key_point}"
    else
      existing_desc
    end
  end

  defp add_character_perspective(existing_desc, _character_name, _), do: existing_desc

  # Extract key points from description/objective
  defp extract_key_points(description, objective) when is_binary(description) or is_binary(objective) do
    combined_text = "#{description} #{objective}" |> String.trim()

    if combined_text == "" do
      []
    else
      # Split into sentences and take first 2-3 meaningful ones
      sentences = combined_text
      |> String.split(~r/[.!?]+/)
      |> Enum.map(&String.trim/1)
      |> Enum.filter(fn s -> String.length(s) > 20 end)  # Filter out very short fragments
      |> Enum.take(3)  # Take up to 3 key points

      # Limit each point to 150 chars
      Enum.map(sentences, fn sentence ->
        String.slice(sentence, 0, 150)
      end)
    end
  end

  defp extract_key_points(_, _), do: []

  # Add character key points to conversation_key_points list
  defp add_character_key_points(existing_key_points, character_name, key_points) when is_list(key_points) do
    if length(key_points) > 0 do
      new_entry = %{
        "character_name" => character_name,
        "key_points" => key_points,
        "added_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
      [new_entry | existing_key_points]
    else
      existing_key_points
    end
  end

  defp add_character_key_points(existing_key_points, _character_name, _), do: existing_key_points

  defp extract_key_point(description) when is_binary(description) and description != "" do
    # Take first sentence or first 100 chars
    first_sentence = description
    |> String.split(".")
    |> List.first()

    if first_sentence do
      String.slice(first_sentence, 0..100)
    else
      String.slice(description, 0..100)
    end
  end
  defp extract_key_point(_), do: ""

  # Extract quest text for embedding (combines title + objective + description)
  def extract_quest_text_for_embedding(quest_data) when is_map(quest_data) do
    title = Map.get(quest_data, "title") || Map.get(quest_data, :title) || ""
    objective = Map.get(quest_data, "objective") || Map.get(quest_data, :objective) || ""
    description = Map.get(quest_data, "description") || Map.get(quest_data, :description) || ""

    # Combine all fields, normalize whitespace
    [title, objective, description]
    |> Enum.filter(fn text -> text != "" end)
    |> Enum.join(" ")
    |> String.trim()
  end

  def extract_quest_text_for_embedding(%UserQuest{} = quest) do
    title = quest.title || ""
    objective = quest.objective || ""
    description = quest.description || ""

    [title, objective, description]
    |> Enum.filter(fn text -> text != "" end)
    |> Enum.join(" ")
    |> String.trim()
  end

  def extract_quest_text_for_embedding(_), do: ""

  # Check if two texts share important keywords (e.g., both contain "bokashi")
  defp has_matching_keywords?(text1, text2) when is_binary(text1) and is_binary(text2) do
    # Extract significant words (3+ characters, lowercase)
    words1 = extract_significant_words(text1)
    words2 = extract_significant_words(text2)

    # Check for overlap in significant words
    common_words = MapSet.intersection(MapSet.new(words1), MapSet.new(words2))

    # If they share 2+ significant words, likely related
    MapSet.size(common_words) >= 2
  end

  defp has_matching_keywords?(_, _), do: false

  defp extract_significant_words(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.split(~r/\W+/)
    |> Enum.filter(fn word -> String.length(word) >= 3 end)
  end

  defp extract_significant_words(_), do: []
end
