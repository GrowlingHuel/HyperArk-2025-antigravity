defmodule GreenManTavern.Quests.ProgressionHandler do
  @moduledoc """
  Handles quest completion and skill progression consequences.

  This module processes quest completion by:
  - Awarding XP rewards to user skills
  - Detecting skill level-ups
  - Recalculating quest difficulties when skills change
  - Updating quest status and timestamps

  ## Usage

      iex> ProgressionHandler.complete_quest(123)
      {:ok, %{
        quest: %UserQuest{...},
        skills_updated: [...],
        level_ups: ["planting", "composting"]
      }}
  """

  require Logger
  import Ecto.Query, warn: false
  alias GreenManTavern.{Quests, Repo, Skills}
  alias GreenManTavern.Quests.{UserQuest, DifficultyCalculator}

  @doc """
  Completes a quest and handles all progression consequences.

  This function:
  1. Loads the quest record
  2. Awards XP rewards to user skills
  3. Detects skill level-ups
  4. Recalculates quest difficulties if skills leveled up
  5. Updates quest status to "completed"
  6. Updates completed_at timestamp

  Returns `{:ok, result_map}` or `{:error, reason}`.

  ## Examples

      iex> ProgressionHandler.complete_quest(123)
      {:ok, %{
        quest: %UserQuest{...},
        skills_updated: [
          {%UserSkill{domain: "planting", ...}, level_up: true},
          {%UserSkill{domain: "composting", ...}, level_up: false}
        ],
        level_ups: ["planting"]
      }}
  """
  def complete_quest(user_quest_id) when is_integer(user_quest_id) do
    try do
      # Step 1: Load the quest record
      user_quest = Quests.get_user_quest!(user_quest_id)

      # Step 2: Extract xp_rewards
      xp_rewards = user_quest.xp_rewards || %{}

      if map_size(xp_rewards) == 0 do
        # No XP rewards, just mark as completed
        case update_quest_completion(user_quest) do
          {:ok, updated_quest} ->
            {:ok, %{
              quest: updated_quest,
              skills_updated: [],
              level_ups: []
            }}
          {:error, _reason} = error ->
            error
        end
      else
        # Step 3: Award XP to each domain
        quest_title = get_quest_title(user_quest)
        evidence = %{"source" => "completed_quest", "quest_title" => quest_title}

        case Skills.bulk_award_xp(user_quest.user_id, xp_rewards, evidence) do
          {:ok, skills_results} ->
            # Extract level-up information
            {skills_updated, level_ups} = extract_level_ups(skills_results)

            # Step 4: If any skills leveled up, recalculate quest difficulties
            difficulty_changes = if level_ups != [] do
              recalculate_all_quest_difficulties(user_quest.user_id)
            else
              []
            end

            # Step 5 & 6: Update quest status and completed_at
            case update_quest_completion(user_quest) do
              {:ok, updated_quest} ->
                {:ok, %{
                  quest: updated_quest,
                  skills_updated: skills_updated,
                  level_ups: level_ups,
                  difficulty_changes: difficulty_changes
                }}

              {:error, _reason} = error ->
                Logger.error("Failed to update quest completion: #{inspect(error)}")
                error
            end

          {:error, reason} = error ->
            Logger.error("Failed to award XP: #{inspect(reason)}")
            error
        end
      end
    rescue
      Ecto.NoResultsError ->
        {:error, :quest_not_found}
      error ->
        Logger.error("Quest completion error: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Recalculates difficulty for all available and active quests for a user.

  This is called after skill level-ups to update the Quest Log in real-time.

  Returns a list of quests that changed difficulty.

  ## Examples

      iex> ProgressionHandler.recalculate_all_quest_difficulties(1)
      [
        %UserQuest{id: 123, calculated_difficulty: 5, ...},
        %UserQuest{id: 456, calculated_difficulty: 3, ...}
      ]
  """
  def recalculate_all_quest_difficulties(user_id) when is_integer(user_id) do
    # Step 1: Load all available/active quests for user
    quests =
      from(uq in UserQuest,
        where: uq.user_id == ^user_id,
        where: uq.status in ["available", "active"],
        preload: [:quest]
      )
      |> Repo.all()

    # Step 2 & 3: For each quest, calculate difficulty and update
    changed_quests =
      quests
      |> Enum.filter(fn user_quest ->
        recalculate_quest_difficulty(user_quest)
      end)

    changed_quests
  end

  defp extract_level_ups(skills_results) do
    {skills_updated, level_ups} =
      skills_results
      |> Enum.reduce({[], []}, fn {skill, level_up: level_up}, {skills_acc, level_ups_acc} ->
        skills_acc = [{skill, level_up: level_up} | skills_acc]
        level_ups_acc = if level_up, do: [skill.domain | level_ups_acc], else: level_ups_acc
        {skills_acc, level_ups_acc}
      end)

    {Enum.reverse(skills_updated), Enum.reverse(level_ups)}
  end

  defp recalculate_quest_difficulty(user_quest) do
    # Calculate new difficulty
    difficulty_result = DifficultyCalculator.calculate_difficulty(user_quest.user_id, user_quest)

    # Convert difficulty string to integer (1-10 scale)
    new_difficulty = difficulty_to_integer(difficulty_result.overall_difficulty)

    # Only update if difficulty changed
    if new_difficulty != user_quest.calculated_difficulty do
      case update_quest_difficulty(user_quest, new_difficulty) do
        {:ok, updated_quest} ->
          Logger.info("Quest #{user_quest.id} difficulty changed from #{user_quest.calculated_difficulty} to #{new_difficulty}")
          updated_quest
        {:error, _reason} ->
          nil
      end
    else
      nil
    end
  end

  defp update_quest_difficulty(user_quest, calculated_difficulty) do
    user_quest
    |> UserQuest.changeset(%{calculated_difficulty: calculated_difficulty})
    |> Repo.update()
  end

  defp update_quest_completion(user_quest) do
    user_quest
    |> UserQuest.changeset(%{
      status: "completed",
      completed_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  defp get_quest_title(user_quest) do
    if user_quest.quest do
      user_quest.quest.title || "Untitled Quest"
    else
      "Unknown Quest"
    end
  end

  defp difficulty_to_integer("easy"), do: 3
  defp difficulty_to_integer("medium"), do: 6
  defp difficulty_to_integer("hard"), do: 9
  defp difficulty_to_integer(_), do: 5
end
