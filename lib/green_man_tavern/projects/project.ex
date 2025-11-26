defmodule GreenManTavern.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  schema "projects" do
    field :name, :string
    field :description, :string
    field :category, :string
    field :inputs, :map
    field :outputs, :map
    field :constraints, {:array, :string}
    field :icon_name, :string
    field :skill_level, :string

    timestamps(type: :naive_datetime, updated_at: false)
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :description, :category, :inputs, :outputs, :constraints, :icon_name, :skill_level])
    |> validate_required([:name, :category])
  end
end
