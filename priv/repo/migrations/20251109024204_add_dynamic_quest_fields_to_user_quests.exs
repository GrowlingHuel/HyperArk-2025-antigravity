defmodule GreenManTavern.Repo.Migrations.AddDynamicQuestFieldsToUserQuests do
  use Ecto.Migration

  def up do
    # Drop the foreign key constraint temporarily so we can modify the column
    execute "ALTER TABLE user_quests DROP CONSTRAINT IF EXISTS user_quests_quest_id_fkey"

    # Make quest_id nullable to support dynamic quests that don't reference the quests table
    execute "ALTER TABLE user_quests ALTER COLUMN quest_id DROP NOT NULL"

    # Re-add the foreign key constraint with the same on_delete behavior
    execute """
    ALTER TABLE user_quests
    ADD CONSTRAINT user_quests_quest_id_fkey
    FOREIGN KEY (quest_id)
    REFERENCES quests(id)
    ON DELETE CASCADE
    """

    # Add dynamic quest fields for AI-generated quests
    # These fields store quest data inline when quest_id is NULL
    alter table(:user_quests) do
      add :title, :string, null: true
      add :description, :text, null: true
      add :objective, :text, null: true
      add :steps, :jsonb, null: true, default: fragment("'[]'::jsonb")
    end

    # Note: Index on generated_by_character_id already exists from previous migration
    # Note: required_skills, calculated_difficulty, xp_rewards, generated_by_character_id,
    #       and conversation_context already exist from previous migration
  end

  def down do
    # Remove the new dynamic quest fields
    alter table(:user_quests) do
      remove :steps
      remove :objective
      remove :description
      remove :title
    end

    # Drop the foreign key constraint
    execute "ALTER TABLE user_quests DROP CONSTRAINT IF EXISTS user_quests_quest_id_fkey"

    # Make quest_id NOT NULL again (this will fail if there are NULL values)
    execute "ALTER TABLE user_quests ALTER COLUMN quest_id SET NOT NULL"

    # Re-add the foreign key constraint
    execute """
    ALTER TABLE user_quests
    ADD CONSTRAINT user_quests_quest_id_fkey
    FOREIGN KEY (quest_id)
    REFERENCES quests(id)
    ON DELETE CASCADE
    """
  end
end
