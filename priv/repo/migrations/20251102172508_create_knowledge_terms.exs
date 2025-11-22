defmodule GreenManTavern.Repo.Migrations.CreateKnowledgeTerms do
  use Ecto.Migration

  def change do
    create table(:knowledge_terms) do
      add :term, :string, null: false
      add :summary, :text, null: false
      add :source, :string, default: "wikipedia"
      add :fetched_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:knowledge_terms, [:term])
  end
end
