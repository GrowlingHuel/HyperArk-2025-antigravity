defmodule GreenManTavern.PlantingGuide.UserPlant do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :user_id, :plant_id, :city_id, :status, :planting_date_start, :planting_date_end, :expected_harvest_date, :actual_planting_date, :actual_harvest_date, :notes, :planting_method, :inserted_at, :updated_at]}

  schema "user_plants" do
    field :status, :string
    field :planting_date_start, :date
    field :planting_date_end, :date
    field :expected_harvest_date, :date
    field :actual_planting_date, :date
    field :actual_harvest_date, :date
    field :notes, :string
    field :planting_method, :string, default: "seeds"
    field :harvest_date_override, :date
    field :living_web_node_id, :string

    belongs_to :user, GreenManTavern.Accounts.User
    belongs_to :plant, GreenManTavern.PlantingGuide.Plant
    belongs_to :city, GreenManTavern.PlantingGuide.City
    belongs_to :planting_quest, GreenManTavern.Quests.UserQuest, foreign_key: :planting_quest_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_plant, attrs) do
    user_plant
    |> cast(attrs, [:user_id, :plant_id, :city_id, :status, :planting_date_start, :planting_date_end, :expected_harvest_date, :actual_planting_date, :actual_harvest_date, :notes, :planting_method, :planting_quest_id, :harvest_date_override, :living_web_node_id])
    |> validate_required([:user_id, :plant_id, :status])
    |> validate_inclusion(:status, ["interested", "will_plant", "planted", "harvested"])
    |> validate_inclusion(:planting_method, ["seeds", "seedlings"],
      message: "must be 'seeds' or 'seedlings'"
    )
    |> validate_status_dates()
    |> foreign_key_constraint(:planting_quest_id)
    |> unique_constraint([:user_id, :plant_id])
  end

  defp validate_status_dates(changeset) do
    status = get_field(changeset, :status)

    case status do
      "harvested" ->
        if get_field(changeset, :actual_harvest_date) do
          changeset
        else
          add_error(changeset, :actual_harvest_date, "must be set when status is harvested")
        end

      _ ->
        changeset
    end
  end

  @doc """
  Calculates expected harvest date based on planting date and days to harvest.

  Returns nil if planting_date is nil.
  """
  def calculate_expected_harvest_date(nil, _days_to_harvest_max), do: nil

  def calculate_expected_harvest_date(planting_date, days_to_harvest_max) when is_struct(planting_date, Date) and is_integer(days_to_harvest_max) do
    Date.add(planting_date, days_to_harvest_max)
  end

  def calculate_expected_harvest_date(_planting_date, _days_to_harvest_max), do: nil

  @doc """
  Gets the expected harvest date for a user plant.

  If harvest_date_override exists, returns it.
  Otherwise calculates: planting_date + plant.days_to_harvest_max.

  Returns date or nil if calculation not possible.

  Note: user_plant.plant must be preloaded for calculation to work.
  """
  def get_expected_harvest_date(%__MODULE__{} = user_plant) do
    # Check for override first
    if user_plant.harvest_date_override do
      user_plant.harvest_date_override
    else
      # Calculate from planting date and plant maturity
      planting_date = user_plant.actual_planting_date || user_plant.planting_date_start || user_plant.planting_date_end

      # Check if plant is loaded and has maturity data
      plant = case user_plant.plant do
        %Ecto.Association.NotLoaded{} -> nil
        nil -> nil
        plant -> plant
      end

      if planting_date && plant do
        days_to_maturity = plant.days_to_harvest_max || plant.days_to_harvest_min

        if days_to_maturity do
          Date.add(planting_date, days_to_maturity)
        else
          nil
        end
      else
        nil
      end
    end
  end

  def get_expected_harvest_date(_), do: nil
end
