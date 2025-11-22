defmodule GreenManTavern.Repo.Migrations.AddQuestDifficultyAndSkillTrackingToUserQuests do
  use Ecto.Migration

  def change do
    alter table(:user_quests) do
      # Required skills for this quest (format: {"planting": 5, "system_building": 7})
      # Maps skill domain to required level
      add :required_skills, :jsonb, null: true, default: fragment("'{}'::jsonb")

      # Calculated difficulty on 1-10 scale (calculated dynamically based on user's skills)
      add :calculated_difficulty, :integer, null: true

      # XP rewards per skill domain (format: {"planting": 50, "composting": 30})
      add :xp_rewards, :jsonb, null: true, default: fragment("'{}'::jsonb")

      # Which character suggested/generated this quest
      add :generated_by_character_id, references(:characters, on_delete: :nilify_all), null: true

      # Brief context of the conversation that generated this quest
      add :conversation_context, :text, null: true
    end

    # Index on generated_by_character_id for fast lookups
    create index(:user_quests, [:generated_by_character_id])
  end
end
