defmodule GreenManTavern.Repo.Migrations.AddQuestDeduplicationFields do
  use Ecto.Migration

  def up do
    # Add topic_tags array field
    alter table(:user_quests) do
      add :topic_tags, {:array, :text}, default: fragment("'{}'")
    end

    # Add suggested_by_character_ids array field
    alter table(:user_quests) do
      add :suggested_by_character_ids, {:array, :integer}, default: fragment("'{}'")
    end

    # Add merged_from_conversations array field
    alter table(:user_quests) do
      add :merged_from_conversations, {:array, :text}, default: fragment("'{}'")
    end

    # Create GIN index on topic_tags for efficient array searches
    create index(:user_quests, [:topic_tags], using: :gin, name: :idx_user_quests_topic_tags)

    # Create GIN index on suggested_by_character_ids for efficient array searches
    create index(:user_quests, [:suggested_by_character_ids], using: :gin, name: :idx_user_quests_suggested_by)
  end

  def down do
    # Drop indexes first (drop by explicit name since we created them with names)
    execute("DROP INDEX IF EXISTS idx_user_quests_suggested_by", "CREATE INDEX idx_user_quests_suggested_by ON user_quests USING GIN(suggested_by_character_ids)")
    execute("DROP INDEX IF EXISTS idx_user_quests_topic_tags", "CREATE INDEX idx_user_quests_topic_tags ON user_quests USING GIN(topic_tags)")

    # Remove the fields
    alter table(:user_quests) do
      remove :merged_from_conversations
      remove :suggested_by_character_ids
      remove :topic_tags
    end
  end
end
