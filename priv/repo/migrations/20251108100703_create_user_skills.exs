defmodule GreenManTavern.Repo.Migrations.CreateUserSkills do
  use Ecto.Migration

  def change do
    create table(:user_skills) do
      add :user_id, references(:users, on_delete: :delete_all), null: false

      # Domain-specific skill area
      # Valid values: "planting", "composting", "system_building", "water_management",
      #               "waste_cycling", "connection_making", "maintenance"
      add :domain, :string, null: false

      # Skill level progression
      # Valid values: "novice", "beginner", "intermediate", "advanced", "expert"
      add :level, :string, null: false, default: "novice"

      # Experience points accumulated in this domain
      add :experience_points, :integer, null: false, default: 0

      # Array of evidence items (stored as JSONB for flexibility)
      add :evidence, :jsonb, default: fragment("'[]'::jsonb")

      # Last time this skill was updated
      add :last_updated, :utc_datetime, null: false

      # Manual timestamp fields using PostgreSQL's NOW() to avoid Elixir 1.18.2 bug
      add :inserted_at, :naive_datetime, null: false, default: fragment("NOW()")
      add :updated_at, :naive_datetime, null: false, default: fragment("NOW()")
    end

    # Unique constraint: each user has one row per domain
    create unique_index(:user_skills, [:user_id, :domain])

    # Index on user_id for fast lookups of all skills for a user
    create index(:user_skills, [:user_id])
  end
end
