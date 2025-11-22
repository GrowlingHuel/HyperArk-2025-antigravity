defmodule GreenManTavern.Repo.Migrations.AddPortsToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :input_ports, {:array, :string}, default: []
      add :output_ports, {:array, :string}, default: []
    end
  end
end
