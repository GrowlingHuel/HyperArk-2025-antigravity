defmodule GreenManTavern.Repo.Migrations.AddInternalDataToCompositeSystems do
  use Ecto.Migration

  def change do
    alter table(:composite_systems) do
      add :internal_nodes_data, :map, default: %{}
      add :internal_edges_data, :map, default: %{}
    end
  end
end
