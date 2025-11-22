defmodule GreenManTavern.Repo.Migrations.AddSessionIdToJournalEntries do
  use Ecto.Migration

  def up do
    # Check if column already exists (idempotent check)
    # PostgreSQL doesn't have a direct "IF NOT EXISTS" for columns, so we use a DO block
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'journal_entries'
        AND column_name = 'conversation_session_id'
      ) THEN
        ALTER TABLE journal_entries
        ADD COLUMN conversation_session_id uuid;

        CREATE INDEX journal_entries_conversation_session_id_index
        ON journal_entries(conversation_session_id);
      END IF;
    END $$;
    """
  end

  def down do
    # Check if column exists before dropping
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'journal_entries'
        AND column_name = 'conversation_session_id'
      ) THEN
        DROP INDEX IF EXISTS journal_entries_conversation_session_id_index;
        ALTER TABLE journal_entries
        DROP COLUMN conversation_session_id;
      END IF;
    END $$;
    """
  end
end









