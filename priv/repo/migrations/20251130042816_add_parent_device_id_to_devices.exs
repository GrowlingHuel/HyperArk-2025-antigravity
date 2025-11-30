defmodule GreenManTavern.Repo.Migrations.AddParentDeviceIdToDevices do
  use Ecto.Migration

  def change do
    alter table(:devices) do
      add :parent_device_id, references(:devices, on_delete: :delete_all, type: :binary_id)
    end

    create index(:devices, [:parent_device_id])
  end
end
