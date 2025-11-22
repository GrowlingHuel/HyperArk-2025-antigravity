defmodule GreenManTavern.Skills do
  @moduledoc """
  The Skills context for managing user skill progression.

  This module provides functions for managing domain-specific skill progression
  across 7 skill domains: planting, composting, system_building, water_management,
  waste_cycling, connection_making, and maintenance.

  ## Skill Levels

  - novice: Starting level (0 XP)
  - beginner: 50 XP required
  - intermediate: 200 XP total required
  - advanced: 500 XP total required
  - expert: 1000 XP total required
  """

  require Logger
  import Ecto.Query, warn: false
  alias GreenManTavern.Repo
  alias GreenManTavern.Skills.UserSkill

  @all_domains ~w(planting composting system_building water_management waste_cycling connection_making maintenance)

  # Level-up thresholds (total XP required)
  @level_thresholds %{
    "novice" => 0,
    "beginner" => 50,
    "intermediate" => 200,
    "advanced" => 500,
    "expert" => 1000
  }

  @doc """
  Returns all 7 domain skills for a user.

  Creates skills with defaults (novice/0 XP) if they don't exist.

  ## Examples

      iex> get_user_skills(1)
      [%UserSkill{domain: "planting", ...}, ...]

  """
  def get_user_skills(user_id) when is_integer(user_id) do
    existing_skills =
      from(us in UserSkill,
        where: us.user_id == ^user_id,
        order_by: us.domain
      )
      |> Repo.all()

    existing_domains = Enum.map(existing_skills, & &1.domain) |> MapSet.new()

    # Find missing domains and create them
    missing_domains =
      @all_domains
      |> Enum.reject(&MapSet.member?(existing_domains, &1))

    new_skills =
      if missing_domains != [] do
        now = DateTime.utc_now()

        missing_domains
        |> Enum.map(fn domain ->
          %UserSkill{}
          |> UserSkill.changeset(%{
            user_id: user_id,
            domain: domain,
            level: "novice",
            experience_points: 0,
            evidence: [],
            last_updated: now
          })
        end)
        |> Enum.map(&Repo.insert!/1)
      else
        []
      end

    # Combine and sort by domain
    (existing_skills ++ new_skills)
    |> Enum.sort_by(& &1.domain)
  end

  @doc """
  Returns a specific domain skill for a user.

  Creates the skill with defaults (novice/0 XP) if it doesn't exist.

  ## Examples

      iex> get_user_skill(1, "planting")
      %UserSkill{domain: "planting", level: "novice", experience_points: 0, ...}

      iex> get_user_skill(1, "invalid_domain")
      {:error, :invalid_domain}

  """
  def get_user_skill(user_id, domain) when is_integer(user_id) and is_binary(domain) do
    if domain in @all_domains do
      case Repo.get_by(UserSkill, user_id: user_id, domain: domain) do
        nil ->
          # Create skill with defaults
          now = DateTime.utc_now()

          %UserSkill{}
          |> UserSkill.changeset(%{
            user_id: user_id,
            domain: domain,
            level: "novice",
            experience_points: 0,
            evidence: [],
            last_updated: now
          })
          |> Repo.insert!()

        skill ->
          skill
      end
    else
      {:error, :invalid_domain}
    end
  end

  @doc """
  Awards XP to a user's skill in a specific domain.

  Checks for level-up and updates level if threshold is crossed.
  Adds evidence to the evidence array.

  Returns `{:ok, skill, level_up: boolean}` or `{:error, reason}`.

  ## Examples

      iex> award_xp(1, "planting", 50, %{source: "quest_completion"})
      {:ok, %UserSkill{...}, level_up: true}

      iex> award_xp(1, "invalid_domain", 50, %{})
      {:error, :invalid_domain}

  """
  def award_xp(user_id, domain, amount, evidence \\ %{})
      when is_integer(user_id) and is_binary(domain) and is_integer(amount) and amount > 0 do
    if domain in @all_domains do
        case get_user_skill(user_id, domain) do
          {:error, _reason} = error ->
            error

        skill ->
          old_level = skill.level
          old_xp = skill.experience_points
          new_xp = old_xp + amount

          # Check for level-up
          new_level = calculate_level(new_xp)
          level_up = new_level != old_level

          # Prepare evidence item with timestamp
          evidence_item =
            evidence
            |> Map.put("xp_awarded", amount)
            |> Map.put("timestamp", DateTime.utc_now() |> DateTime.to_iso8601())

          now = DateTime.utc_now()

          changeset =
            skill
            |> UserSkill.changeset(%{
              experience_points: new_xp,
              level: new_level,
              evidence: (skill.evidence || []) ++ [evidence_item],
              last_updated: now
            })

          case Repo.update(changeset) do
            {:ok, updated_skill} ->
              {:ok, updated_skill, level_up: level_up}

            {:error, changeset} ->
              {:error, changeset}
          end
      end
    else
      {:error, :invalid_domain}
    end
  end

  @doc """
  Determines if a skill should level up based on current XP.

  Returns the appropriate level for the given XP amount.

  ## Examples

      iex> check_level_up(%UserSkill{experience_points: 50, level: "novice"})
      "beginner"

      iex> check_level_up(%UserSkill{experience_points: 25, level: "novice"})
      "novice"

  """
  def check_level_up(%UserSkill{} = skill) do
    calculate_level(skill.experience_points)
  end

  defp calculate_level(xp) when is_integer(xp) and xp >= 0 do
    cond do
      xp >= @level_thresholds["expert"] -> "expert"
      xp >= @level_thresholds["advanced"] -> "advanced"
      xp >= @level_thresholds["intermediate"] -> "intermediate"
      xp >= @level_thresholds["beginner"] -> "beginner"
      true -> "novice"
    end
  end

  @doc """
  Initializes all 7 domain skills at novice/0 XP for a new user.

  Returns `{:ok, [skills]}` or `{:error, reason}`.

  ## Examples

      iex> initialize_user_skills(1)
      {:ok, [%UserSkill{domain: "planting", ...}, ...]}

  """
  def initialize_user_skills(user_id) when is_integer(user_id) do
    try do
      now = DateTime.utc_now()

      skills =
        @all_domains
        |> Enum.map(fn domain ->
          %UserSkill{}
          |> UserSkill.changeset(%{
            user_id: user_id,
            domain: domain,
            level: "novice",
            experience_points: 0,
            evidence: [],
            last_updated: now
          })
        end)
        |> Enum.map(&Repo.insert!/1)

      {:ok, skills}
    rescue
      error ->
        Logger.error("Failed to initialize user skills: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Awards XP to multiple domains at once.

  Example: `bulk_award_xp(1, %{"planting" => 50, "composting" => 30}, %{source: "quest"})`

  Returns `{:ok, [skills]}` with level_up information, or `{:error, reason}`.

  ## Examples

      iex> bulk_award_xp(1, %{"planting" => 50, "composting" => 30}, %{source: "quest"})
      {:ok, [
        {%UserSkill{domain: "planting", ...}, level_up: true},
        {%UserSkill{domain: "composting", ...}, level_up: false}
      ]}

  """
  def bulk_award_xp(user_id, xp_map, evidence \\ %{})
      when is_integer(user_id) and is_map(xp_map) do
    try do
      results =
        xp_map
        |> Enum.map(fn {domain, amount} ->
          case award_xp(user_id, domain, amount, evidence) do
            {:ok, skill, level_up: level_up} ->
              {:ok, {skill, level_up: level_up}}

            {:error, _reason} = error ->
              error
          end
        end)

      # Check if any failed
      errors = Enum.filter(results, &match?({:error, _reason}, &1))

      if errors != [] do
        {:error, {:partial_failure, errors}}
      else
        successful =
          results
          |> Enum.map(fn {:ok, result} -> result end)
        {:ok, successful}
      end
    rescue
      error ->
        Logger.error("Bulk XP award failed: #{inspect(error)}")
        {:error, error}
    end
  end
end
