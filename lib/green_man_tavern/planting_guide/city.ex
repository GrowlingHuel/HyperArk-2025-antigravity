defmodule GreenManTavern.PlantingGuide.City do
  use Ecto.Schema
  import Ecto.Changeset

  alias GreenManTavern.PlantingGuide.{KoppenZone, CityFrostDate}

  @derive {Jason.Encoder,
           only: [
             :id,
             :city_name,
             :country,
             :state_province_territory,
             :latitude,
             :longitude,
             :koppen_code,
             :hemisphere,
             :notes,
             :inserted_at,
             :updated_at
           ]}

  schema "cities" do
    field :city_name, :string
    field :country, :string
    field :state_province_territory, :string
    field :latitude, :decimal
    field :longitude, :decimal
    field :koppen_code, :string
    field :hemisphere, :string
    field :notes, :string

    belongs_to :koppen_zone, KoppenZone,
      foreign_key: :koppen_code,
      references: :code,
      define_field: false

    has_one :frost_date, CityFrostDate

    timestamps(type: :naive_datetime)
  end

  @doc false
  def changeset(city, attrs) do
    city
    |> cast(attrs, [
      :city_name,
      :country,
      :state_province_territory,
      :latitude,
      :longitude,
      :koppen_code,
      :hemisphere,
      :notes
    ])
    |> validate_required([:city_name, :country, :koppen_code, :hemisphere])
    |> validate_inclusion(:hemisphere, ["Northern", "Southern"])
    |> foreign_key_constraint(:koppen_code)
  end
end
