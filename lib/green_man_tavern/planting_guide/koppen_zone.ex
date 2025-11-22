defmodule GreenManTavern.PlantingGuide.KoppenZone do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :code,
             :name,
             :category,
             :description,
             :temperature_pattern,
             :precipitation_pattern,
             :inserted_at,
             :updated_at
           ]}

  schema "koppen_zones" do
    field :code, :string
    field :name, :string
    field :category, :string
    field :description, :string
    field :temperature_pattern, :string
    field :precipitation_pattern, :string

    timestamps(type: :naive_datetime)
  end

  @doc false
  def changeset(koppen_zone, attrs) do
    koppen_zone
    |> cast(attrs, [
      :code,
      :name,
      :category,
      :description,
      :temperature_pattern,
      :precipitation_pattern
    ])
    |> validate_required([:code, :name, :category])
    |> validate_length(:code, max: 3)
    |> unique_constraint(:code)
  end
end
