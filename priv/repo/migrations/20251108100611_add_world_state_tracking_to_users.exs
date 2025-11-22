defmodule GreenManTavern.Repo.Migrations.AddWorldStateTrackingToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Current season in the game world
      # Valid values: "spring", "summer", "autumn", "winter"
      add :current_season, :string, null: true

      # Days into the current growing season
      add :days_into_growing_season, :integer, null: true, default: nil

      # Active projects state (stored as JSONB for flexibility)
      add :active_projects_state, :jsonb, null: true, default: fragment("'{}'::jsonb")
    end
  end
end
