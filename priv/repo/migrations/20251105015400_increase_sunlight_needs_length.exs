defmodule GreenManTavern.Repo.Migrations.IncreaseSunlightNeedsLength do
  use Ecto.Migration

  def change do
    alter table(:plants) do
      modify :sunlight_needs, :string, size: 30
    end
  end
end
