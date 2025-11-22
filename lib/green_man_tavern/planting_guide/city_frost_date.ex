defmodule GreenManTavern.PlantingGuide.CityFrostDate do
  use Ecto.Schema
  import Ecto.Changeset

  alias GreenManTavern.PlantingGuide.City

  @derive {Jason.Encoder, only: [:id, :city_id, :last_frost_date, :first_frost_date,
                                  :growing_season_days, :data_source, :confidence_level,
                                  :notes, :inserted_at, :updated_at]}

  schema "city_frost_dates" do
    belongs_to :city, City

    field :last_frost_date, :string
    field :first_frost_date, :string
    field :growing_season_days, :integer
    field :data_source, :string
    field :confidence_level, :string
    field :notes, :string

    timestamps()
  end

  @doc false
  def changeset(city_frost_date, attrs) do
    city_frost_date
    |> cast(attrs, [:city_id, :last_frost_date, :first_frost_date, :growing_season_days,
                    :data_source, :confidence_level, :notes])
    |> validate_required([:city_id, :last_frost_date, :first_frost_date, :growing_season_days,
                          :data_source, :confidence_level])
    |> validate_inclusion(:confidence_level, ["high", "medium", "low"])
    |> foreign_key_constraint(:city_id)
    |> unique_constraint(:city_id)
  end
end
