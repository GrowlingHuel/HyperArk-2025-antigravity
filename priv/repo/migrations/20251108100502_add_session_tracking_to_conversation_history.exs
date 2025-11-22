defmodule GreenManTavern.Repo.Migrations.AddSessionTrackingToConversationHistory do
  use Ecto.Migration

  def change do
    alter table(:conversation_history) do
      # Session ID for grouping messages into sessions
      # Stored as UUID type in PostgreSQL for efficient storage and indexing
      add :session_id, :uuid, null: true

      # Session summary - the journal entry generated at session end
      add :session_summary, :text, null: true

      # Session-level fact extraction (stored as JSONB for flexibility)
      add :extracted_facts, :jsonb, null: true
    end

    # Index session_id for fast queries by session
    create index(:conversation_history, [:session_id])
  end
end
