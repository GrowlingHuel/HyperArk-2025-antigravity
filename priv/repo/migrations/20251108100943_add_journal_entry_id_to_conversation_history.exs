defmodule GreenManTavern.Repo.Migrations.AddJournalEntryIdToConversationHistory do
  use Ecto.Migration

  def change do
    alter table(:conversation_history) do
      # Link to journal entry created from this conversation session
      # Allows storing summary in conversation_history.session_summary AND
      # optionally creating a journal_entries record that references it
      add :journal_entry_id, references(:journal_entries, on_delete: :nilify_all), null: true
    end

    # Index on journal_entry_id for fast lookups
    create index(:conversation_history, [:journal_entry_id])
  end
end
