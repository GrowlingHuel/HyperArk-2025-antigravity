defmodule GreenManTavern.Repo.Migrations.AddPositionToDevices do
  use Ecto.Migration

  def change do
    alter table(:devices) do
      add :position_x, :float, default: 0.0
      add :position_y, :float, default: 0.0
    end
  end
end
