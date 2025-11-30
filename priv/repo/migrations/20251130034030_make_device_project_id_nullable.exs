defmodule GreenManTavern.Repo.Migrations.MakeDeviceProjectIdNullable do
  use Ecto.Migration

  def change do
    alter table(:devices) do
      modify :project_id, :integer, null: true, from: {:integer, null: false}
    end
  end
end
