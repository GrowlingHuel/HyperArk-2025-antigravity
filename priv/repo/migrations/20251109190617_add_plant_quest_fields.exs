defmodule GreenManTavern.Repo.Migrations.AddPlantQuestFields do
  use Ecto.Migration

  def up do
    # Add plant quest tracking fields to user_quests table
    alter table(:user_quests) do
      add :quest_type, :string, size: 50, null: true
      add :plant_tracking, :jsonb, default: fragment("'[]'::jsonb")
      add :date_window_start, :date, null: true
      add :date_window_end, :date, null: true
      add :planting_complete, :boolean, default: false
      add :harvest_complete, :boolean, default: false
    end

    # Add index on quest_type for filtering
    create index(:user_quests, [:quest_type])

    # Add index on date_window_start for date range queries
    create index(:user_quests, [:date_window_start])
  end

  def down do
    # Drop indexes first
    drop index(:user_quests, [:date_window_start])
    drop index(:user_quests, [:quest_type])

    # Remove the plant quest tracking fields
    alter table(:user_quests) do
      remove :harvest_complete
      remove :planting_complete
      remove :date_window_end
      remove :date_window_start
      remove :plant_tracking
      remove :quest_type
    end
  end
end
