defmodule GreenManTavern.PlantingGuide.Plant do
  use Ecto.Schema
  import Ecto.Changeset

  alias GreenManTavern.PlantingGuide.CompanionRelationship
  alias GreenManTavern.PlantingGuide.PlantFamily

  @derive {Jason.Encoder,
           only: [
             :id,
             :common_name,
             :scientific_name,
             :plant_family,
             :plant_type,
             :climate_zones,
             :growing_difficulty,
             :space_required,
             :sunlight_needs,
             :water_needs,
             :days_to_germination_min,
             :days_to_germination_max,
             :days_to_harvest_min,
             :days_to_harvest_max,
             :perennial_annual,
             :planting_months_sh,
             :planting_months_nh,
             :height_cm_min,
             :height_cm_max,
             :spread_cm_min,
             :spread_cm_max,
             :native_region,
             :description,
             :family_id,
             :transplant_friendly,
             :typical_seedling_age_days,
             :direct_sow_only,
             :seedling_difficulty,
             :transplant_notes,
             :inserted_at,
             :updated_at
           ]}

  schema "plants" do
    field :common_name, :string
    field :scientific_name, :string
    field :plant_family, :string
    field :plant_type, :string
    field :climate_zones, {:array, :string}
    field :growing_difficulty, :string
    field :space_required, :string
    field :sunlight_needs, :string
    field :water_needs, :string
    field :days_to_germination_min, :integer
    field :days_to_germination_max, :integer
    field :days_to_harvest_min, :integer
    field :days_to_harvest_max, :integer
    field :perennial_annual, :string
    field :planting_months_sh, :string
    field :planting_months_nh, :string
    field :height_cm_min, :integer
    field :height_cm_max, :integer
    field :spread_cm_min, :integer
    field :spread_cm_max, :integer
    field :native_region, :string
    field :description, :string
    field :family_id, :id
    field :transplant_friendly, :boolean, default: true
    field :typical_seedling_age_days, :integer
    field :direct_sow_only, :boolean, default: false
    field :seedling_difficulty, :string
    field :transplant_notes, :string

    belongs_to :family, PlantFamily, define_field: false
    has_many :companion_relationships_a, CompanionRelationship, foreign_key: :plant_a_id
    has_many :companion_relationships_b, CompanionRelationship, foreign_key: :plant_b_id

    timestamps(type: :naive_datetime)
  end

  @doc false
  def changeset(plant, attrs) do
    plant
    |> cast(attrs, [
      :common_name,
      :scientific_name,
      :plant_family,
      :plant_type,
      :climate_zones,
      :growing_difficulty,
      :space_required,
      :sunlight_needs,
      :water_needs,
      :days_to_germination_min,
      :days_to_germination_max,
      :days_to_harvest_min,
      :days_to_harvest_max,
      :perennial_annual,
      :planting_months_sh,
      :planting_months_nh,
      :height_cm_min,
      :height_cm_max,
      :spread_cm_min,
      :spread_cm_max,
      :native_region,
      :description,
      :family_id,
      :transplant_friendly,
      :typical_seedling_age_days,
      :direct_sow_only,
      :seedling_difficulty,
      :transplant_notes
    ])
    |> validate_required([:common_name, :climate_zones])
    |> validate_climate_zones_not_empty()
    |> validate_inclusion(:growing_difficulty, ["Easy", "Moderate", "Hard"],
      message: "must be Easy, Moderate, or Hard"
    )
    |> validate_inclusion(:seedling_difficulty, ["Easy", "Moderate", "Hard"],
      message: "must be Easy, Moderate, or Hard"
    )
    |> validate_transplant_and_direct_sow()
  end

  # Custom validator to ensure climate_zones array is not empty
  defp validate_climate_zones_not_empty(changeset) do
    validate_change(changeset, :climate_zones, fn :climate_zones, climate_zones ->
      cond do
        is_nil(climate_zones) ->
          [climate_zones: "cannot be nil"]

        is_list(climate_zones) and length(climate_zones) == 0 ->
          [climate_zones: "cannot be empty"]

        is_list(climate_zones) ->
          []

        true ->
          [climate_zones: "must be an array"]
      end
    end)
  end

  # Custom validator: if direct_sow_only is true, transplant_friendly should be false
  defp validate_transplant_and_direct_sow(changeset) do
    direct_sow_only = get_field(changeset, :direct_sow_only)
    transplant_friendly = get_field(changeset, :transplant_friendly)

    if direct_sow_only == true && transplant_friendly == true do
      add_error(changeset, :transplant_friendly,
        "must be false when direct_sow_only is true"
      )
    else
      changeset
    end
  end

  @doc """
  Returns true if the plant can be transplanted as a seedling.
  """
  def can_transplant?(plant) do
    plant.transplant_friendly && !plant.direct_sow_only
  end

  @doc """
  Returns the typical seedling age in days, defaulting to 42 (6 weeks) if not set.
  """
  def get_seedling_age(plant) do
    plant.typical_seedling_age_days || 42
  end

  @doc """
  Returns the effective difficulty for a given planting method.

  For seedlings method:
  - Returns "Hard" if direct_sow_only is true
  - Returns seedling_difficulty if set, otherwise falls back to growing_difficulty

  For other methods, returns growing_difficulty.
  """
  def get_effective_difficulty(plant, method) when method in [:seedlings, "seedlings"] do
    if plant.direct_sow_only do
      "Hard" # Seedlings not recommended
    else
      plant.seedling_difficulty || plant.growing_difficulty
    end
  end

  def get_effective_difficulty(plant, _method), do: plant.growing_difficulty
end
