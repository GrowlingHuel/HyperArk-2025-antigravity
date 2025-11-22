defmodule GreenManTavern.Repo.Migrations.AddPgvectorAndQuestEmbeddings do
  use Ecto.Migration

  def up do
    # Enable pgvector extension
    execute("CREATE EXTENSION IF NOT EXISTS vector")

    # Add description_embedding field to user_quests table
    # Using vector(1536) for OpenAI text-embedding-3-small model
    alter table(:user_quests) do
      add :description_embedding, :vector, size: 1536
    end

    # Create index for fast similarity search using cosine distance
    # ivfflat index is efficient for similarity searches
    # Note: Ecto doesn't support 'with' option, so we use raw SQL
    # We filter by user_id in WHERE clause, so single column vector index is sufficient
    execute("""
    CREATE INDEX idx_user_quests_description_embedding
    ON user_quests
    USING ivfflat (description_embedding vector_cosine_ops)
    """)
  end

  def down do
    # Drop index using raw SQL
    execute("DROP INDEX IF EXISTS idx_user_quests_description_embedding")

    # Remove description_embedding field
    alter table(:user_quests) do
      remove :description_embedding
    end

    # Note: We don't drop the vector extension as it might be used by other tables
    # If needed, manually run: DROP EXTENSION IF EXISTS vector;
  end
end
