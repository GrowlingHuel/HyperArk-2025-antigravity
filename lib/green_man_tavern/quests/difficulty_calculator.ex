defmodule GreenManTavern.Quests.DifficultyCalculator do
  @moduledoc """
  Calculates quest difficulty for a specific user based on their skill levels.

  This module compares a quest's required skills against a user's current
  skill levels to determine how difficult the quest will be for that user.

  ## Usage

      iex> quest = %{required_skills: %{"planting" => 5, "system_building" => 7}}
      iex> DifficultyCalculator.calculate_difficulty(1, quest)
      %{
        overall_difficulty: "medium",
        skill_breakdown: [...],
        skills_ready: ["planting"],
        skills_challenging: ["system_building"],
        readiness_ratio: "1/2 skills ready"
      }
  """

  alias GreenManTavern.Skills

  # Skill level to numeric capability score mapping
  @level_scores %{
    "novice" => 1,
    "beginner" => 3,
    "intermediate" => 6,
    "advanced" => 8,
    "expert" => 10
  }

  @doc """
  Calculates how difficult a quest is for a specific user.

  Returns a map with:
  - overall_difficulty: "easy" | "medium" | "hard"
  - skill_breakdown: list of skill analysis maps
  - skills_ready: list of domain names where user is ready
  - skills_challenging: list of domain names where user needs improvement
  - readiness_ratio: string like "1/2 skills ready"

  ## Parameters

  - user_id: The user's ID
  - quest: A map or struct with `required_skills` field (map of domain => required_level)

  ## Examples

      iex> quest = %{required_skills: %{"planting" => 5, "system_building" => 7}}
      iex> DifficultyCalculator.calculate_difficulty(1, quest)
      %{
        overall_difficulty: "medium",
        skill_breakdown: [
          %{domain: "planting", required: 5, user_level: 6, status: "ready"},
          %{domain: "system_building", required: 7, user_level: 3, status: "challenging"}
        ],
        skills_ready: ["planting"],
        skills_challenging: ["system_building"],
        readiness_ratio: "1/2 skills ready"
      }
  """
  def calculate_difficulty(user_id, quest) when is_integer(user_id) do
    # Extract required_skills from quest (handle both map and struct)
    required_skills = extract_required_skills(quest)

    if map_size(required_skills) == 0 do
      # No required skills - quest is easy
      %{
        overall_difficulty: "easy",
        skill_breakdown: [],
        skills_ready: [],
        skills_challenging: [],
        readiness_ratio: "0/0 skills ready"
      }
    else
      # Load user's skills
      user_skills = Skills.get_user_skills(user_id)
      user_skills_map = Map.new(user_skills, &{&1.domain, &1})

      # Analyze each required skill
      skill_breakdown_with_gap =
        required_skills
        |> Enum.map(fn {domain, required_level} ->
          analyze_skill(domain, required_level, user_skills_map)
        end)

      # Determine overall difficulty based on highest gap (before removing gap field)
      overall_difficulty = calculate_overall_difficulty(skill_breakdown_with_gap)

      # Remove internal gap field from output
      skill_breakdown = Enum.map(skill_breakdown_with_gap, &Map.delete(&1, :_gap))

      # Categorize skills
      skills_ready =
        skill_breakdown
        |> Enum.filter(&(&1.status == "ready"))
        |> Enum.map(& &1.domain)

      skills_challenging =
        skill_breakdown
        |> Enum.filter(&(&1.status == "challenging"))
        |> Enum.map(& &1.domain)

      # Calculate readiness ratio
      total_skills = length(skill_breakdown)
      ready_count = length(skills_ready)
      readiness_ratio = "#{ready_count}/#{total_skills} skills ready"

      %{
        overall_difficulty: overall_difficulty,
        skill_breakdown: skill_breakdown,
        skills_ready: skills_ready,
        skills_challenging: skills_challenging,
        readiness_ratio: readiness_ratio
      }
    end
  end

  defp extract_required_skills(%{required_skills: skills}) when is_map(skills), do: skills
  defp extract_required_skills(%{"required_skills" => skills}) when is_map(skills), do: skills
  defp extract_required_skills(skills) when is_map(skills), do: skills
  defp extract_required_skills(_), do: %{}

  defp analyze_skill(domain, required_level, user_skills_map) do
    # Get user's skill for this domain (default to novice if not found)
    user_skill = Map.get(user_skills_map, domain)

    user_capability =
      if user_skill do
        level_to_capability(user_skill.level)
      else
        # Default to novice if user doesn't have this skill
        @level_scores["novice"]
      end

    # Calculate gap
    gap = required_level - user_capability

    # Determine status based on gap
    status = determine_status(gap)

    %{
      domain: domain,
      required: required_level,
      user_level: user_capability,
      status: status,
      _gap: gap  # Internal use only for overall difficulty calculation
    }
  end

  defp level_to_capability(level) when is_binary(level) do
    Map.get(@level_scores, level, @level_scores["novice"])
  end
  defp level_to_capability(_), do: @level_scores["novice"]

  defp determine_status(gap) when gap <= 1, do: "ready"
  defp determine_status(gap) when gap >= 2, do: "challenging"

  defp calculate_overall_difficulty(skill_breakdown) do
    if skill_breakdown == [] do
      "easy"
    else
      # Find the maximum gap (using internal _gap field)
      max_gap =
        skill_breakdown
        |> Enum.map(&Map.get(&1, :_gap, 0))
        |> Enum.max()

      cond do
        max_gap <= 1 -> "easy"
        max_gap >= 2 and max_gap <= 3 -> "medium"
        max_gap >= 4 -> "hard"
        true -> "medium"
      end
    end
  end
end
