defmodule GreenManTavern.PlantingGuide do
  @moduledoc """
  The PlantingGuide context.

  Provides functions for managing Köppen climate zones, cities, plants, and companion relationships.
  Includes advanced querying for climate-based plant recommendations and companion planting.
  """

  import Ecto.Query, warn: false
  alias GreenManTavern.Repo

  alias GreenManTavern.PlantingGuide.{KoppenZone, City, Plant, CompanionRelationship, CityFrostDate, UserPlant}

  # ======================
  # Köppen Zones
  # ======================

  @doc """
  Returns all Köppen zones ordered by category, then code.

  ## Examples

      iex> list_koppen_zones()
      [%KoppenZone{category: "Continental", code: "Dfa"}, ...]

  """
  def list_koppen_zones do
    KoppenZone
    |> order_by([k], [k.category, k.code])
    |> Repo.all()
  end

  @doc """
  Gets a single Köppen zone by its code.

  Raises `Ecto.NoResultsError` if the Köppen zone does not exist.

  ## Examples

      iex> get_koppen_zone!("Cfb")
      %KoppenZone{code: "Cfb", name: "Oceanic"}

      iex> get_koppen_zone!("XYZ")
      ** (Ecto.NoResultsError)

  """
  def get_koppen_zone!(code) when is_binary(code) do
    Repo.get_by!(KoppenZone, code: code)
  end

  @doc """
  Creates a Köppen zone.

  ## Examples

      iex> create_koppen_zone(%{code: "Cfb", name: "Oceanic", category: "Temperate"})
      {:ok, %KoppenZone{}}

      iex> create_koppen_zone(%{code: "X"})
      {:error, %Ecto.Changeset{}}

  """
  def create_koppen_zone(attrs \\ %{}) do
    %KoppenZone{}
    |> KoppenZone.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a Köppen zone.

  ## Examples

      iex> update_koppen_zone(zone, %{name: "New Name"})
      {:ok, %KoppenZone{}}

  """
  def update_koppen_zone(%KoppenZone{} = koppen_zone, attrs) do
    koppen_zone
    |> KoppenZone.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Köppen zone.

  ## Examples

      iex> delete_koppen_zone(zone)
      {:ok, %KoppenZone{}}

  """
  def delete_koppen_zone(%KoppenZone{} = koppen_zone) do
    Repo.delete(koppen_zone)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking Köppen zone changes.

  ## Examples

      iex> change_koppen_zone(zone)
      %Ecto.Changeset{data: %KoppenZone{}}

  """
  def change_koppen_zone(%KoppenZone{} = koppen_zone, attrs \\ %{}) do
    KoppenZone.changeset(koppen_zone, attrs)
  end

  # ======================
  # Cities
  # ======================

  @doc """
  Returns list of cities with optional filtering.

  ## Filters

  - `:country` - Filter by country name (exact match)
  - `:koppen_code` - Filter by Köppen climate code
  - `:hemisphere` - Filter by hemisphere ("Northern" or "Southern")

  Results are ordered by country, then city_name, and preload Köppen zone.

  ## Examples

      iex> list_cities()
      [%City{}, ...]

      iex> list_cities(%{country: "Australia"})
      [%City{country: "Australia"}, ...]

      iex> list_cities(%{koppen_code: "Cfb", hemisphere: "Southern"})
      [%City{}, ...]

  """
  def list_cities(filters \\ %{}) do
    City
    |> apply_city_filters(filters)
    |> order_by([c], [c.country, c.city_name])
    |> preload(:koppen_zone)
    |> Repo.all()
  end

  defp apply_city_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:country, country}, query when is_binary(country) ->
        where(query, [c], c.country == ^country)

      {:koppen_code, code}, query when is_binary(code) ->
        where(query, [c], c.koppen_code == ^code)

      {:hemisphere, hemisphere}, query when is_binary(hemisphere) ->
        where(query, [c], c.hemisphere == ^hemisphere)

      _, query ->
        query
    end)
  end

  @doc """
  Gets a single city with preloaded Köppen zone.

  Raises `Ecto.NoResultsError` if the City does not exist.

  ## Examples

      iex> get_city!(123)
      %City{id: 123, koppen_zone: %KoppenZone{}}

      iex> get_city!(999)
      ** (Ecto.NoResultsError)

  """
  def get_city!(id) do
    City
    |> preload(:koppen_zone)
    |> Repo.get!(id)
  end

  @doc """
  Gets all cities in a specific Köppen climate zone.

  ## Examples

      iex> get_cities_by_koppen("Cfb")
      [%City{koppen_code: "Cfb"}, ...]

  """
  def get_cities_by_koppen(koppen_code) when is_binary(koppen_code) do
    City
    |> where([c], c.koppen_code == ^koppen_code)
    |> order_by([c], [c.country, c.city_name])
    |> preload(:koppen_zone)
    |> Repo.all()
  end

  @doc """
  Creates a city.

  ## Examples

      iex> create_city(%{city_name: "Melbourne", country: "Australia", ...})
      {:ok, %City{}}

  """
  def create_city(attrs \\ %{}) do
    %City{}
    |> City.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a city.

  ## Examples

      iex> update_city(city, %{notes: "Updated notes"})
      {:ok, %City{}}

  """
  def update_city(%City{} = city, attrs) do
    city
    |> City.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a city.

  ## Examples

      iex> delete_city(city)
      {:ok, %City{}}

  """
  def delete_city(%City{} = city) do
    Repo.delete(city)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking city changes.

  ## Examples

      iex> change_city(city)
      %Ecto.Changeset{data: %City{}}

  """
  def change_city(%City{} = city, attrs \\ %{}) do
    City.changeset(city, attrs)
  end

  # ======================
  # Plants
  # ======================

  @doc """
  Returns list of plants with optional filtering.

  ## Filters

  - `:climate_zone` - Filter plants suitable for Köppen code (searches array)
  - `:plant_type` - Filter by plant type (e.g., "Vegetable", "Herb")
  - `:growing_difficulty` - Filter by difficulty ("Easy", "Moderate", "Hard")
  - `:hemisphere` - Filter by hemisphere ("Northern" or "Southern") based on planting_months presence
  - `:month` - Filter by planting month (e.g., "Sep", "Mar") - searches planting_months strings

  Results are ordered by common_name.

  ## Examples

      iex> list_plants()
      [%Plant{}, ...]

      iex> list_plants(%{climate_zone: "Cfb"})
      [%Plant{climate_zones: ["Cfb", ...]}, ...]

      iex> list_plants(%{plant_type: "Vegetable", growing_difficulty: "Easy"})
      [%Plant{}, ...]

      iex> list_plants(%{hemisphere: "Southern", month: "Sep"})
      [%Plant{planting_months_sh: "Sep-Nov"}, ...]

  """
  def list_plants(filters \\ %{}) do
    Plant
    |> apply_plant_filters(filters)
    |> order_by([p], p.common_name)
    |> Repo.all()
  end

  defp apply_plant_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:climate_zone, code}, query when is_binary(code) ->
        # PostgreSQL array contains operator
        where(query, [p], fragment("? = ANY(?)", ^code, p.climate_zones))

      {:plant_type, type}, query when is_binary(type) ->
        where(query, [p], p.plant_type == ^type)

      {:growing_difficulty, difficulty}, query when is_binary(difficulty) ->
        where(query, [p], p.growing_difficulty == ^difficulty)

      {:hemisphere, "Northern"}, query ->
        where(query, [p], not is_nil(p.planting_months_nh))

      {:hemisphere, "Southern"}, query ->
        where(query, [p], not is_nil(p.planting_months_sh))

      {:month, month}, query when is_binary(month) ->
        # Search for month abbreviation in planting_months fields
        where(
          query,
          [p],
          fragment("? ILIKE ?", p.planting_months_nh, ^"%#{month}%") or
            fragment("? ILIKE ?", p.planting_months_sh, ^"%#{month}%")
        )

      _, query ->
        query
    end)
  end

  @doc """
  Gets a single plant.

  Raises `Ecto.NoResultsError` if the Plant does not exist.

  ## Examples

      iex> get_plant!(123)
      %Plant{}

      iex> get_plant!(999)
      ** (Ecto.NoResultsError)

  """
  def get_plant!(id) do
    Repo.get!(Plant, id)
  end

  @doc """
  Searches plants by common name or scientific name (case-insensitive).

  ## Examples

      iex> search_plants("tomato")
      [%Plant{common_name: "Tomato"}, %Plant{scientific_name: "Solanum lycopersicum"}]

      iex> search_plants("basil")
      [%Plant{common_name: "Basil"}, ...]

  """
  def search_plants(query_string) when is_binary(query_string) do
    search_pattern = "%#{query_string}%"

    Plant
    |> where(
      [p],
      ilike(p.common_name, ^search_pattern) or
        ilike(p.scientific_name, ^search_pattern)
    )
    |> order_by([p], p.common_name)
    |> Repo.all()
  end

  def search_plants(_), do: []

  @doc """
  Creates a plant.

  ## Examples

      iex> create_plant(%{common_name: "Tomato", climate_zones: ["Cfb"]})
      {:ok, %Plant{}}

  """
  def create_plant(attrs \\ %{}) do
    %Plant{}
    |> Plant.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a plant.

  ## Examples

      iex> update_plant(plant, %{description: "Updated description"})
      {:ok, %Plant{}}

  """
  def update_plant(%Plant{} = plant, attrs) do
    plant
    |> Plant.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a plant.

  ## Examples

      iex> delete_plant(plant)
      {:ok, %Plant{}}

  """
  def delete_plant(%Plant{} = plant) do
    Repo.delete(plant)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking plant changes.

  ## Examples

      iex> change_plant(plant)
      %Ecto.Changeset{data: %Plant{}}

  """
  def change_plant(%Plant{} = plant, attrs \\ %{}) do
    Plant.changeset(plant, attrs)
  end

  # ======================
  # Companion Relationships
  # ======================

  @doc """
  Gets companion plants for a specific plant, optionally filtered by relationship type.

  Returns a list of maps containing:
  - `:plant` - The companion Plant struct
  - `:relationship_type` - "good" or "bad"
  - `:evidence_level` - "scientific", "traditional_strong", or "traditional_weak"
  - `:mechanism` - How the relationship works
  - `:notes` - Additional notes

  This function checks relationships bidirectionally (where the plant is either plant_a or plant_b).

  ## Examples

      iex> get_companions(tomato_id)
      [%{plant: %Plant{common_name: "Basil"}, relationship_type: "good", ...}, ...]

      iex> get_companions(tomato_id, "good")
      [%{plant: %Plant{}, relationship_type: "good", ...}]

      iex> get_companions(tomato_id, "bad")
      [%{plant: %Plant{}, relationship_type: "bad", ...}]

  """
  def get_companions(plant_id, relationship_type \\ nil) do
    # Find relationships where plant is plant_a
    relationships_as_a =
      CompanionRelationship
      |> where([cr], cr.plant_a_id == ^plant_id)
      |> maybe_filter_relationship_type(relationship_type)
      |> preload(:plant_b)
      |> Repo.all()
      |> Enum.map(fn rel ->
        %{
          plant: rel.plant_b,
          relationship_type: rel.relationship_type,
          evidence_level: rel.evidence_level,
          mechanism: rel.mechanism,
          notes: rel.notes
        }
      end)

    # Find relationships where plant is plant_b
    relationships_as_b =
      CompanionRelationship
      |> where([cr], cr.plant_b_id == ^plant_id)
      |> maybe_filter_relationship_type(relationship_type)
      |> preload(:plant_a)
      |> Repo.all()
      |> Enum.map(fn rel ->
        %{
          plant: rel.plant_a,
          relationship_type: rel.relationship_type,
          evidence_level: rel.evidence_level,
          mechanism: rel.mechanism,
          notes: rel.notes
        }
      end)

    relationships_as_a ++ relationships_as_b
  end

  defp maybe_filter_relationship_type(query, nil), do: query

  defp maybe_filter_relationship_type(query, type) when type in ["good", "bad"] do
    where(query, [cr], cr.relationship_type == ^type)
  end

  defp maybe_filter_relationship_type(query, _), do: query

  @doc """
  Gets the companion relationship details between two specific plants.

  Checks both directions (A→B and B→A) and returns the relationship if it exists.

  ## Examples

      iex> get_companion_details(tomato_id, basil_id)
      %CompanionRelationship{relationship_type: "good", ...}

      iex> get_companion_details(plant1_id, plant2_id)
      nil

  """
  def get_companion_details(plant_a_id, plant_b_id) do
    # Try A→B direction
    case Repo.get_by(CompanionRelationship, plant_a_id: plant_a_id, plant_b_id: plant_b_id) do
      nil ->
        # Try B→A direction
        Repo.get_by(CompanionRelationship, plant_a_id: plant_b_id, plant_b_id: plant_a_id)

      relationship ->
        relationship
    end
  end

  @doc """
  Creates a companion relationship.

  ## Examples

      iex> create_companion_relationship(%{plant_a_id: 1, plant_b_id: 2, relationship_type: "good", ...})
      {:ok, %CompanionRelationship{}}

  """
  def create_companion_relationship(attrs \\ %{}) do
    %CompanionRelationship{}
    |> CompanionRelationship.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a companion relationship.

  ## Examples

      iex> update_companion_relationship(relationship, %{mechanism: "Updated mechanism"})
      {:ok, %CompanionRelationship{}}

  """
  def update_companion_relationship(%CompanionRelationship{} = companion_relationship, attrs) do
    companion_relationship
    |> CompanionRelationship.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a companion relationship.

  ## Examples

      iex> delete_companion_relationship(relationship)
      {:ok, %CompanionRelationship{}}

  """
  def delete_companion_relationship(%CompanionRelationship{} = companion_relationship) do
    Repo.delete(companion_relationship)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking companion relationship changes.

  ## Examples

      iex> change_companion_relationship(relationship)
      %Ecto.Changeset{data: %CompanionRelationship{}}

  """
  def change_companion_relationship(
        %CompanionRelationship{} = companion_relationship,
        attrs \\ %{}
      ) do
    CompanionRelationship.changeset(companion_relationship, attrs)
  end

  # ======================
  # Helper Functions
  # ======================

  @doc """
  Gets all plants compatible with a city's Köppen climate zone.

  ## Examples

      iex> plants_for_city(melbourne_id)
      [%Plant{climate_zones: ["Cfb", ...]}, ...]

  """
  def plants_for_city(city_id) do
    case Repo.get(City, city_id) do
      nil ->
        []

      %City{koppen_code: koppen_code} ->
        list_plants(%{climate_zone: koppen_code})
    end
  end

  @doc """
  Gets plants that are compatible with a city AND can be planted in a specific month.

  Takes into account the city's hemisphere to check the appropriate planting_months field.

  ## Examples

      iex> plants_plantable_now(melbourne_id, "Sep")
      [%Plant{planting_months_sh: "Sep-Nov"}, ...]

      iex> plants_plantable_now(london_id, "Mar")
      [%Plant{planting_months_nh: "Mar-May"}, ...]

  """
  def plants_plantable_now(city_id, month) when is_binary(month) do
    case Repo.get(City, city_id) do
      nil ->
        []

      %City{koppen_code: koppen_code, hemisphere: hemisphere} ->
        Plant
        |> where([p], fragment("? = ANY(?)", ^koppen_code, p.climate_zones))
        |> filter_by_hemisphere_and_month(hemisphere, month)
        |> order_by([p], p.common_name)
        |> Repo.all()
    end
  end

  def plants_plantable_now(_, _), do: []

  defp filter_by_hemisphere_and_month(query, "Northern", month) do
    where(query, [p], fragment("? ILIKE ?", p.planting_months_nh, ^"%#{month}%"))
  end

  defp filter_by_hemisphere_and_month(query, "Southern", month) do
    where(query, [p], fragment("? ILIKE ?", p.planting_months_sh, ^"%#{month}%"))
  end

  defp filter_by_hemisphere_and_month(query, _, _), do: query

  # ======================
  # Frost Dates
  # ======================

  @doc """
  Returns a list of city IDs that have frost date data available.

  ## Examples

      iex> list_cities_with_frost_dates()
      [1, 2, 5, 10, ...]

  """
  def list_cities_with_frost_dates do
    CityFrostDate
    |> select([cfd], cfd.city_id)
    |> Repo.all()
  end

  @doc """
  Gets the frost date information for a specific city.

  Returns the CityFrostDate struct with preloaded city association, or nil if no frost data exists.

  ## Examples

      iex> get_frost_dates(city_id)
      %CityFrostDate{last_frost_date: "September 20", first_frost_date: "April 15", ...}

      iex> get_frost_dates(nonexistent_city_id)
      nil

  """
  def get_frost_dates(city_id) do
    CityFrostDate
    |> where([cfd], cfd.city_id == ^city_id)
    |> preload(:city)
    |> Repo.one()
  end

  @doc """
  Calculates recommended planting dates for a specific plant in a specific city.

  Takes into account:
  - City's frost dates (if available)
  - Plant's frost sensitivity
  - Plant's days to harvest
  - City's hemisphere for planting month ranges

  Returns a map with:
  - `plant_after_date`: Earliest safe planting date
  - `plant_before_date`: Latest planting date to harvest before first frost
  - `explanation`: Human-readable explanation of the dates

  ## Examples

      iex> calculate_planting_date(city_id, plant_id)
      %{
        plant_after_date: "October 4",
        plant_before_date: "March 1",
        explanation: "Plant after last frost (Sept 20) + 14 days for frost-sensitive plant"
      }

  """
  def calculate_planting_date(city_id, plant_id) do
    with {:ok, city} <- get_city_with_frost(city_id),
         {:ok, plant} <- get_plant_for_planting(plant_id),
         {:ok, frost_dates} <- get_frost_dates_for_calculation(city_id) do
      calculate_dates(city, plant, frost_dates)
    else
      {:error, reason} -> %{error: reason}
    end
  end

  defp get_city_with_frost(city_id) do
    case Repo.get(City, city_id) do
      nil -> {:error, "City not found"}
      city -> {:ok, city}
    end
  end

  defp get_plant_for_planting(plant_id) do
    case Repo.get(Plant, plant_id) do
      nil -> {:error, "Plant not found"}
      plant -> {:ok, plant}
    end
  end

  defp get_frost_dates_for_calculation(city_id) do
    case get_frost_dates(city_id) do
      nil -> {:ok, nil}
      frost_dates -> {:ok, frost_dates}
    end
  end

  defp calculate_dates(city, plant, nil) do
    # No frost data - use planting month ranges
    month_field = if city.hemisphere == "Southern", do: :planting_months_sh, else: :planting_months_nh
    months = Map.get(plant, month_field, "")

    %{
      plant_after_date: "Beginning of #{months}",
      plant_before_date: "End of #{months}",
      explanation: "No frost data available. Plant during recommended months: #{months}"
    }
  end

  defp calculate_dates(city, plant, frost_dates) do
    case {frost_dates.last_frost_date, frost_dates.first_frost_date} do
      {"No frost", "No frost"} ->
        # Tropical region - use month ranges
        month_field = if city.hemisphere == "Southern", do: :planting_months_sh, else: :planting_months_nh
        months = Map.get(plant, month_field, "")

        %{
          plant_after_date: "Year-round (no frost)",
          plant_before_date: "Year-round (no frost)",
          explanation: "This is a frost-free region. You can plant year-round during: #{months}"
        }

      {last_frost, first_frost} ->
        # Calculate based on frost dates
        days_offset = get_frost_offset_days(plant)
        plant_after = add_days_to_date(last_frost, days_offset)

        # Calculate plant before date (working backwards from first frost)
        days_to_harvest = plant.days_to_harvest_max || plant.days_to_harvest_min || 90
        plant_before = subtract_days_from_date(first_frost, days_to_harvest)

        sensitivity = if days_offset == 14, do: "frost-sensitive", else: "hardy"

        %{
          plant_after_date: plant_after,
          plant_before_date: plant_before,
          explanation:
            "Plant after last frost (#{last_frost}) + #{days_offset} days for #{sensitivity} plant. " <>
              "Harvest #{days_to_harvest} days before first frost (#{first_frost})."
        }
    end
  end

  # Determines frost sensitivity based on plant type
  defp get_frost_offset_days(plant) do
    frost_sensitive = ["Fruit", "Vegetable"]
    hardy_types = ["Herb", "Cover Crop", "Native"]

    cond do
      plant.plant_type in frost_sensitive && plant.common_name =~ ~r/tomato|capsicum|pepper|eggplant|cucumber|zucchini/i ->
        14

      plant.plant_type in hardy_types || plant.common_name =~ ~r/brassica|cabbage|kale|broccoli|pea|lettuce/i ->
        7

      true ->
        10
    end
  end

  @doc """
  Parses a date string into a month and day tuple.

  ## Examples

      iex> parse_date_string("September 20")
      {9, 20}

      iex> parse_date_string("No frost")
      :no_frost

      iex> parse_date_string("Invalid")
      {:error, "Invalid date format"}

  """
  def parse_date_string("No frost"), do: :no_frost
  def parse_date_string(nil), do: {:error, "Date is nil"}

  def parse_date_string(date_str) when is_binary(date_str) do
    month_map = %{
      "January" => 1,
      "February" => 2,
      "March" => 3,
      "April" => 4,
      "May" => 5,
      "June" => 6,
      "July" => 7,
      "August" => 8,
      "September" => 9,
      "October" => 10,
      "November" => 11,
      "December" => 12
    }

    case String.split(date_str, " ", parts: 2) do
      [month_name, day_str] ->
        with {:ok, month} <- Map.fetch(month_map, month_name),
             {day, ""} <- Integer.parse(day_str) do
          {month, day}
        else
          _ -> {:error, "Invalid date format"}
        end

      _ ->
        {:error, "Invalid date format"}
    end
  end

  @doc """
  Adds a specified number of days to a date string.

  ## Examples

      iex> add_days_to_date("September 20", 14)
      "October 4"

      iex> add_days_to_date("December 25", 10)
      "January 4"

  """
  def add_days_to_date(date_str, days) when is_binary(date_str) and is_integer(days) do
    case parse_date_string(date_str) do
      :no_frost ->
        "No frost"

      {:error, _} ->
        date_str

      {month, day} ->
        year = get_current_year()

        {:ok, date} = Date.new(year, month, day)
        new_date = Date.add(date, days)

        month_name = month_name_from_number(new_date.month)
        "#{month_name} #{new_date.day}"
    end
  end

  # Subtract days from a date string
  defp subtract_days_from_date(date_str, days) when is_binary(date_str) and is_integer(days) do
    case parse_date_string(date_str) do
      :no_frost ->
        "No frost"

      {:error, _} ->
        date_str

      {month, day} ->
        year = get_current_year()

        {:ok, date} = Date.new(year, month, day)
        new_date = Date.add(date, -days)

        month_name = month_name_from_number(new_date.month)
        "#{month_name} #{new_date.day}"
    end
  end

  @doc """
  Returns the current year as an integer.

  ## Examples

      iex> get_current_year()
      2025

  """
  def get_current_year do
    Date.utc_today().year
  end

  # Helper to convert month number to month name
  defp month_name_from_number(month_num) do
    case month_num do
      1 -> "January"
      2 -> "February"
      3 -> "March"
      4 -> "April"
      5 -> "May"
      6 -> "June"
      7 -> "July"
      8 -> "August"
      9 -> "September"
      10 -> "October"
      11 -> "November"
      12 -> "December"
    end
  end

  # ======================
  # User Plants
  # ======================

  @doc """
  Lists all user plants for a given user, optionally filtered.

  ## Parameters
  - `user_id` - The user ID
  - `filters` - Optional map with filters:
    - `:status` - Filter by status (e.g., "planted", "harvested")
    - `:plant_type` - Filter by plant type

  ## Examples

      iex> list_user_plants(1)
      [%UserPlant{}, ...]

      iex> list_user_plants(1, %{status: "planted"})
      [%UserPlant{status: "planted"}, ...]
  """
  def list_user_plants(user_id, filters \\ %{}) do
    query =
      UserPlant
      |> where([up], up.user_id == ^user_id)
      |> preload([:plant, :city])
      |> order_by([up], desc: up.inserted_at)

    query =
      if status = Map.get(filters, :status) do
        where(query, [up], up.status == ^status)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Gets the user's default city from their profile_data facts.
  First checks profile_data["facts"] for location/city information.
  Falls back to most common city_id from user_plants if no profile data found.
  Returns nil if no city information is found.

  ## Examples

      iex> get_user_default_city_id(1)
      42  # City ID from profile or user_plants

      iex> get_user_default_city_id(999)
      nil  # No city information found
  """
  def get_user_default_city_id(user_id) when is_integer(user_id) do
    alias GreenManTavern.Accounts

    # Try to get user to access profile_data
    try do
      user = Accounts.get_user!(user_id)
      get_user_default_city_from_profile(user)
    rescue
      Ecto.NoResultsError -> nil
    end
  end

  def get_user_default_city_id(_), do: nil

  # Helper: Extract city from profile_data facts, fallback to user_plants
  defp get_user_default_city_from_profile(user) do
    # First, try to get city from profile_data["facts"]
    city_from_facts = extract_city_from_facts(user.profile_data)

    if city_from_facts do
      city_from_facts
    else
      # Fallback: get most common city from user_plants
      get_user_default_city_from_plants(user.id)
    end
  end

  # Extract city name from profile_data["facts"] and try to match it to a city in the database
  defp extract_city_from_facts(profile_data) when is_map(profile_data) do
    facts = Map.get(profile_data, "facts", [])

    # Look for location facts with key "city" or similar
    city_fact = Enum.find(facts, fn fact ->
      fact_type = Map.get(fact, "type", "")
      fact_key = Map.get(fact, "key", "")
      fact_type == "location" && (fact_key == "city" || fact_key == "location" || fact_key == "city_name")
    end)

    if city_fact do
      city_name = Map.get(city_fact, "value", "")

      if city_name != "" do
        # Try to find a matching city in the database
        # Match by city_name (case-insensitive, partial match)
        city = City
        |> where([c], fragment("LOWER(?) LIKE LOWER(?)", c.city_name, ^"%#{city_name}%"))
        |> limit(1)
        |> Repo.one()

        if city, do: city.id, else: nil
      else
        nil
      end
    else
      nil
    end
  end

  defp extract_city_from_facts(_), do: nil

  # Fallback: Get most common city_id from user_plants
  defp get_user_default_city_from_plants(user_id) do
    user_plants_with_city =
      UserPlant
      |> where([up], up.user_id == ^user_id and not is_nil(up.city_id))
      |> select([up], up.city_id)
      |> Repo.all()

    if Enum.empty?(user_plants_with_city) do
      nil
    else
      # Find the most common city_id
      user_plants_with_city
      |> Enum.frequencies()
      |> Enum.max_by(fn {_city_id, count} -> count end, fn -> {nil, 0} end)
      |> elem(0)
    end
  end

  @doc """
  Gets a single user plant by user ID and plant ID.

  Returns `nil` if not found.

  ## Examples

      iex> get_user_plant(1, 5)
      %UserPlant{}

      iex> get_user_plant(1, 999)
      nil
  """
  def get_user_plant(user_id, plant_id) do
    Repo.get_by(UserPlant, user_id: user_id, plant_id: plant_id)
    |> Repo.preload([:plant, :city])
  end

  @doc """
  Creates a user plant record.

  Automatically calculates `expected_harvest_date` if `planting_date_start` is provided
  and the plant has `days_to_harvest_max`.

  ## Examples

      iex> create_user_plant(%{user_id: 1, plant_id: 5, status: "interested"})
      {:ok, %UserPlant{}}

      iex> create_user_plant(%{user_id: 1, plant_id: 5, status: "invalid"})
      {:error, %Ecto.Changeset{}}
  """
  def create_user_plant(attrs \\ %{}) do
    attrs = calculate_harvest_date_if_needed(attrs)

    %UserPlant{}
    |> UserPlant.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user plant record.

  Automatically recalculates `expected_harvest_date` if `planting_date_start` changes
  and the plant has `days_to_harvest_max`.

  ## Examples

      iex> update_user_plant(user_plant, %{status: "planted"})
      {:ok, %UserPlant{}}

      iex> update_user_plant(user_plant, %{status: "invalid"})
      {:error, %Ecto.Changeset{}}
  """
  def update_user_plant(%UserPlant{} = user_plant, attrs) do
    # Reload plant to get latest days_to_harvest_max
    plant = Repo.preload(user_plant, :plant).plant

    attrs =
      attrs
      |> Map.put(:plant_id, user_plant.plant_id)
      |> calculate_harvest_date_if_needed(plant)

    user_plant
    |> UserPlant.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user plant record.

  ## Examples

      iex> delete_user_plant(user_plant)
      {:ok, %UserPlant{}}
  """
  def delete_user_plant(%UserPlant{} = user_plant) do
    Repo.delete(user_plant)
  end

  @doc """
  Gets all user plants with a specific status.

  ## Examples

      iex> get_plants_by_status(1, "planted")
      [%UserPlant{status: "planted"}, ...]
  """
  def get_plants_by_status(user_id, status) do
    UserPlant
    |> where([up], up.user_id == ^user_id and up.status == ^status)
    |> preload([:plant, :city])
    |> order_by([up], desc: up.inserted_at)
    |> Repo.all()
  end

  @doc """
  Counts all user plants for a given user.

  ## Examples

      iex> count_user_plants(1)
      15
  """
  def count_user_plants(user_id) do
    UserPlant
    |> where([up], up.user_id == ^user_id)
    |> Repo.aggregate(:count, :id)
  end

  # Helper function to calculate expected harvest date
  defp calculate_harvest_date_if_needed(attrs, plant \\ nil) do
    planting_date = Map.get(attrs, :planting_date_start)

    if planting_date do
      # Get plant if not provided
      plant =
        plant || if plant_id = Map.get(attrs, :plant_id) do
          get_plant!(plant_id)
        else
          nil
        end

      if plant do
        # Get planting method from attrs, default to :seeds
        method =
          case Map.get(attrs, :planting_method) do
            method when method in [:seeds, "seeds"] -> :seeds
            method when method in [:seedlings, "seedlings"] -> :seedlings
            _ -> :seeds
          end

        harvest_date = calculate_harvest_date(planting_date, plant, method)
        Map.put(attrs, :expected_harvest_date, harvest_date)
      else
        attrs
      end
    else
      attrs
    end
  end

  # ======================
  # Seedling-Aware Planting Calculations
  # ======================

  @doc """
  Calculate planting dates based on method (seeds or seedlings).

  Returns %{start_date: Date.t(), end_date: Date.t()}

  ## Examples

      iex> calculate_planting_window(plant, city, "Sep", :seeds)
      %{start_date: ~D[2025-09-01], end_date: ~D[2025-09-15]}

      iex> calculate_planting_window(plant, city, "Sep", :seedlings)
      %{start_date: ~D[2025-10-13], end_date: ~D[2025-10-27]}

      iex> calculate_planting_window(plant, city, "Sep", :seedlings)
      nil  # If plant cannot be transplanted
  """
  def calculate_planting_window(plant, city, month, method \\ :seeds) do
    # Get base planting window for seeds
    base_start = calculate_seed_planting_start(plant, city, month)
    base_end = calculate_seed_planting_end(plant, city, month)

    case method do
      method when method in [:seedlings, "seedlings"] ->
        if Plant.can_transplant?(plant) do
          # Shift window forward by seedling age
          head_start = Plant.get_seedling_age(plant)
          %{
            start_date: Date.add(base_start, head_start),
            end_date: Date.add(base_end, head_start)
          }
        else
          # Can't transplant - return nil to indicate not available
          nil
        end

      _ -> # :seeds or "seeds"
        %{
          start_date: base_start,
          end_date: base_end
        }
    end
  end

  @doc """
  Calculate harvest date based on planting date and method.

  ## Examples

      iex> calculate_harvest_date(~D[2025-09-01], plant, :seeds)
      ~D[2025-12-01]

      iex> calculate_harvest_date(~D[2025-09-01], plant, :seedlings)
      ~D[2025-11-19]  # Adjusted for seedling age
  """
  def calculate_harvest_date(planting_date, plant, method \\ :seeds) do
    days_to_harvest = plant.days_to_harvest_max || plant.days_to_harvest_min || 90

    case method do
      method when method in [:seedlings, "seedlings"] ->
        # Seedlings already have growth time
        head_start = Plant.get_seedling_age(plant)
        remaining_days = days_to_harvest - head_start
        Date.add(planting_date, max(remaining_days, 0))

      _ -> # :seeds
        Date.add(planting_date, days_to_harvest)
    end
  end

  # Helper functions (add these as private)

  defp calculate_seed_planting_start(_plant, _city, month) do
    # Use existing logic from your planting window calculation
    # Or simplified: first day of selected month
    month_num = month_name_to_number(month)
    Date.new!(Date.utc_today().year, month_num, 1)
  end

  defp calculate_seed_planting_end(plant, city, month) do
    start = calculate_seed_planting_start(plant, city, month)
    Date.add(start, 14) # 2-week planting window
  end

  defp month_name_to_number(month_name) do
    months = %{
      "Jan" => 1,
      "Feb" => 2,
      "Mar" => 3,
      "Apr" => 4,
      "May" => 5,
      "Jun" => 6,
      "Jul" => 7,
      "Aug" => 8,
      "Sep" => 9,
      "Oct" => 10,
      "Nov" => 11,
      "Dec" => 12
    }

    Map.get(months, month_name, 1)
  end

  def preload_plant(%UserPlant{} = user_plant) do
    Repo.preload(user_plant, :plant)
  end
end
