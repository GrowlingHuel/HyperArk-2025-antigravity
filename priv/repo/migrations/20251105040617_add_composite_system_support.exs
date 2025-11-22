defmodule GreenManTavern.Repo.Migrations.AddCompositeSystemSupport do
  use Ecto.Migration

  def change do
    # Add composite system fields to systems table
    alter table(:systems) do
      add :is_composite, :boolean, default: false, null: false
      add :parent_system_id, references(:systems, on_delete: :restrict), null: true
    end

    # Add composite system fields to user_systems table
    alter table(:user_systems) do
      add :is_expanded, :boolean, default: false, null: false
      add :internal_nodes, :map, default: fragment("'{}'::jsonb")
      add :internal_edges, :map, default: fragment("'{}'::jsonb")
    end

    # Create index for parent_system_id lookups
    create index(:systems, [:parent_system_id])
  end
end
