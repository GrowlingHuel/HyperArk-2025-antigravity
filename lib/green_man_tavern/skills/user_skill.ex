defmodule GreenManTavern.Skills.UserSkill do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_domains ~w(planting composting system_building water_management waste_cycling connection_making maintenance)
  @valid_levels ~w(novice beginner intermediate advanced expert)

  schema "user_skills" do
    field :domain, :string
    field :level, :string, default: "novice"
    field :experience_points, :integer, default: 0
    field :evidence, {:array, :map}, default: []
    field :last_updated, :utc_datetime

    timestamps(type: :naive_datetime)

    belongs_to :user, GreenManTavern.Accounts.User
  end

  @doc false
  def changeset(user_skill, attrs) do
    user_skill
    |> cast(attrs, [
      :user_id,
      :domain,
      :level,
      :experience_points,
      :evidence,
      :last_updated
    ])
    |> validate_required([:user_id, :domain, :level, :experience_points, :last_updated])
    |> validate_inclusion(:domain, @valid_domains)
    |> validate_inclusion(:level, @valid_levels)
    |> validate_number(:experience_points, greater_than_or_equal_to: 0)
    |> unique_constraint([:user_id, :domain])
  end

  @doc """
  Adds experience points to a user skill and updates the last_updated timestamp.
  """
  def add_experience(user_skill, points) when is_integer(points) and points > 0 do
    now = DateTime.utc_now()

    user_skill
    |> change(%{
      experience_points: user_skill.experience_points + points,
      last_updated: now
    })
  end

  @doc """
  Adds an evidence item to the evidence array.
  """
  def add_evidence(user_skill, evidence_item) when is_map(evidence_item) do
    now = DateTime.utc_now()

    user_skill
    |> change(%{
      evidence: (user_skill.evidence || []) ++ [evidence_item],
      last_updated: now
    })
  end
end
