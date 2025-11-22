defmodule GreenManTavern.Repo.Migrations.AddSeedlingFieldsToPlants do
  use Ecto.Migration

  def change do
    alter table(:plants) do
      add :transplant_friendly, :boolean, default: true, null: false
      add :typical_seedling_age_days, :integer
      add :direct_sow_only, :boolean, default: false, null: false
      add :seedling_difficulty, :string
      add :transplant_notes, :text
    end
  end
end
