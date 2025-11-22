defmodule GreenManTavern.Repo.Migrations.AddHiddenToJournalEntries do
  use Ecto.Migration

  def change do
    alter table(:journal_entries) do
      add :hidden, :boolean, default: false, null: false
    end
  end
end
