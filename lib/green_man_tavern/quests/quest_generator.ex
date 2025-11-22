defmodule GreenManTavern.Quests.QuestGenerator do
  @moduledoc """
  Creates quest records from AI-generated quest data.

  This module handles the creation of both base Quest templates and UserQuest
  records for AI-generated quests from conversation sessions.

  ## Usage

      iex> quest_data = %{
        title: "Start Your Compost Bin",
        objective: "Build a compost bin...",
        steps: ["step 1", "step 2"],
        required_skills: %{"composting" => 3},
        xp_rewards: %{"composting" => 50}
      }
      iex> QuestGenerator.create_quest_from_session(1, quest_data, 2, "session-id")
      {:ok, %UserQuest{...}}
  """

  require Logger
  alias GreenManTavern.{Quests, Repo}
  alias GreenManTavern.Quests.{UserQuest, DifficultyCalculator, Deduplication}
  alias GreenManTavern.AI.EmbeddingGenerator

  @doc """
  Creates a dynamic quest record directly in user_quests table from AI-generated quest data.

  This function:
  1. Creates a UserQuest record directly (quest_id = NULL for dynamic quests)
  2. Calculates difficulty for the user
  3. Stores the calculated difficulty

  Returns `{:ok, user_quest}` or `{:error, reason}`.

  ## Parameters

  - user_id: The user's ID
  - quest_data: Map with title, objective, steps, required_skills, xp_rewards, difficulty_estimate, etc.
  - character_id: The character who generated this quest
  - session_id: The conversation session ID that generated this quest

  ## Examples

      iex> quest_data = %{
        title: "Start Your Compost Bin",
        objective: "Build a compost bin using The Grandmother's method",
        steps: ["Gather materials", "Build bin", "Start pile"],
        required_skills: %{"composting" => 3, "system_building" => 2},
        xp_rewards: %{"composting" => 50, "system_building" => 30},
        difficulty_estimate: 5
      }
      iex> QuestGenerator.create_quest_from_session(1, quest_data, 2, "session-123")
      {:ok, %UserQuest{...}}
  """
  def create_quest_from_session(user_id, quest_data, character_id, session_id)
      when is_integer(user_id) and is_integer(character_id) and is_binary(session_id) do
    try do
      # Convert difficulty_estimate (1-10) to calculated_difficulty integer
      calculated_difficulty =
        quest_data
        |> Map.get(:difficulty_estimate)
        |> estimate_to_difficulty_integer()

      # Convert steps array to list (ensure it's a list, not a map)
      steps_list =
        case Map.get(quest_data, :steps, []) do
          steps when is_list(steps) -> steps
          steps when is_map(steps) -> Map.values(steps) # Handle if it's a map
          _ -> []
        end

      # Build conversation context
      conversation_context = "Generated from conversation session: #{session_id}"

      # Get quest text for embedding generation (combines title + objective + description)
      # Use same extraction logic as deduplication for consistency
      quest_text = Deduplication.extract_quest_text_for_embedding(quest_data)

      # Generate embedding for quest text (for similarity search)
      description_embedding = case EmbeddingGenerator.generate_embedding(quest_text) do
        {:ok, embedding} ->
          Logger.info("[QuestGenerator] ✅ Generated embedding for quest description")
          embedding
        {:error, reason} ->
          Logger.warning("[QuestGenerator] ⚠️ Failed to generate embedding: #{inspect(reason)}. Quest will be created without embedding.")
          nil
      end

      # Create UserQuest record directly (quest_id = NULL for dynamic quests)
      user_quest_attrs = %{
        user_id: user_id,
        quest_id: nil,  # NULL for dynamically generated quests
        status: "available",
        progress_data: %{},
        # Dynamic quest fields
        title: Map.get(quest_data, :title) || "Untitled Quest",
        description: Map.get(quest_data, :description) || Map.get(quest_data, :objective) || "",
        objective: Map.get(quest_data, :objective) || Map.get(quest_data, :title) || "No objective",
        steps: steps_list,
        # Skill and difficulty fields
        required_skills: Map.get(quest_data, :required_skills, %{}),
        calculated_difficulty: calculated_difficulty,
        xp_rewards: Map.get(quest_data, :xp_rewards, %{}),
        # Metadata fields
        generated_by_character_id: character_id,
        conversation_context: conversation_context,
        # Embedding field (will be converted to vector type in database)
        description_embedding: description_embedding
      }

      # Remove embedding from attrs for initial insert (Ecto doesn't handle vector type natively)
      attrs_without_embedding = Map.delete(user_quest_attrs, :description_embedding)

      case %UserQuest{}
           |> UserQuest.changeset(attrs_without_embedding)
           |> Repo.insert() do
        {:ok, user_quest} ->
          # Update embedding using raw SQL (pgvector requires vector type)
          if description_embedding do
            update_quest_embedding(user_quest.id, description_embedding)
          end

          # Recalculate difficulty based on user's actual skills (may differ from estimate)
          difficulty_result = DifficultyCalculator.calculate_difficulty(user_id, user_quest)
          actual_calculated_difficulty = difficulty_to_integer(difficulty_result.overall_difficulty)

          # Update with actual calculated difficulty
          if actual_calculated_difficulty != calculated_difficulty do
            case update_user_quest_difficulty(user_quest, actual_calculated_difficulty) do
              {:ok, updated_quest} ->
                {:ok, updated_quest}
              {:error, changeset} ->
                Logger.warning("Failed to update quest difficulty: #{inspect(changeset.errors)}")
                # Return the original quest even if difficulty update fails
                {:ok, user_quest}
            end
          else
            {:ok, user_quest}
          end

        {:error, changeset} = error ->
          Logger.error("Failed to create dynamic quest: #{inspect(changeset.errors)}")
          error
      end
    rescue
      error ->
        Logger.error("Quest generation error: #{inspect(error)}")
        {:error, error}
    end
  end

  defp update_user_quest_difficulty(user_quest, calculated_difficulty) do
    user_quest
    |> UserQuest.changeset(%{calculated_difficulty: calculated_difficulty})
    |> Repo.update()
  end

  # Update quest embedding using raw SQL (pgvector requires vector type)
  defp update_quest_embedding(quest_id, embedding) when is_list(embedding) do
    # Convert embedding list to PostgreSQL array format for vector casting
    embedding_array_str = "[" <> Enum.join(Enum.map(embedding, &Float.to_string/1), ",") <> "]"

    sql = """
    UPDATE user_quests
    SET description_embedding = $1::vector
    WHERE id = $2
    """

    case Repo.query(sql, [embedding_array_str, quest_id]) do
      {:ok, _} ->
        Logger.info("[QuestGenerator] ✅ Updated quest #{quest_id} with embedding")
        :ok

      {:error, reason} ->
        Logger.warning("[QuestGenerator] ⚠️ Failed to update embedding: #{inspect(reason)}")
        :error
    end
  end

  defp update_quest_embedding(_quest_id, _), do: :ok

  # Convert difficulty_estimate (1-10) to calculated_difficulty integer (1-10)
  defp estimate_to_difficulty_integer(nil), do: 5  # Default to medium
  defp estimate_to_difficulty_integer(estimate) when is_integer(estimate) do
    # Clamp to 1-10 range
    cond do
      estimate < 1 -> 1
      estimate > 10 -> 10
      true -> estimate
    end
  end
  defp estimate_to_difficulty_integer(_), do: 5

  # Convert difficulty string to integer (1-10 scale)
  defp difficulty_to_integer("easy"), do: 3
  defp difficulty_to_integer("medium"), do: 6
  defp difficulty_to_integer("hard"), do: 9
  defp difficulty_to_integer(_), do: 5
end
