defmodule GreenManTavern.Repo.Migrations.AddCablePatternToPatchCables do
  use Ecto.Migration

  def change do
    alter table(:patch_cables) do
      add :cable_pattern, :string, default: "solid"
    end
  end
end
