defmodule GreenManTavern.Repo.Migrations.AddPlantQuestLink do
  use Ecto.Migration

  def up do
    # Add planting_quest_id and harvest_date_override to user_plants table
    alter table(:user_plants) do
      add :planting_quest_id, references(:user_quests, on_delete: :nilify_all, type: :bigint), null: true
      add :harvest_date_override, :date, null: true
    end

    # Add index on planting_quest_id for efficient lookups
    create index(:user_plants, [:planting_quest_id])
  end

  def down do
    # Drop index first
    drop index(:user_plants, [:planting_quest_id])

    # Remove the fields (foreign key constraint will be dropped automatically)
    alter table(:user_plants) do
      remove :harvest_date_override
      remove :planting_quest_id
    end
  end
end
