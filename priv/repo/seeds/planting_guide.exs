# Planting Guide Database Seed File
#
# This script populates the planting guide database from CSV files.
# Run with: mix run priv/repo/seeds/planting_guide.exs
#
# CSV files expected in: priv/repo/seeds/data/
# - koppen_climate_zones.csv
# - world_cities_climate_zones.csv
# - plants_database_500.csv
# - companion_planting_relationships.csv

alias GreenManTavern.Repo
alias GreenManTavern.PlantingGuide.{KoppenZone, City, Plant, CompanionRelationship}

require Logger

# Setup NimbleCSV parser
NimbleCSV.define(CSVParser, separator: ",", escape: "\"")
alias CSVParser, as: CSV

# Helper module for parsing functions
defmodule SeedHelpers do
  # Helper function to parse range strings like "7-14" → {7, 14}
  def parse_range(nil), do: {nil, nil}
  def parse_range(""), do: {nil, nil}

  def parse_range(range_string) when is_binary(range_string) do
    case String.split(String.trim(range_string), "-") do
      [min, max] ->
        {parse_integer(min), parse_integer(max)}

      [single] ->
        num = parse_integer(single)
        {num, num}

      _ ->
        {nil, nil}
    end
  end

  def parse_range(_), do: {nil, nil}

  # Helper to safely parse integers
  def parse_integer(str) when is_binary(str) do
    case Integer.parse(String.trim(str)) do
      {num, _} -> num
      :error -> nil
    end
  end

  def parse_integer(_), do: nil

  # Helper to parse climate zones array like "Cfa,Cfb,Csa" → ["Cfa", "Cfb", "Csa"]
  def parse_climate_zones(nil), do: []
  def parse_climate_zones(""), do: []

  def parse_climate_zones(zones_string) when is_binary(zones_string) do
    zones_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  def parse_climate_zones(_), do: []

  # Helper to parse decimal values
  def parse_decimal(nil), do: nil
  def parse_decimal(""), do: nil

  # Handle tuples - use try/catch to handle ANY tuple structure
  def parse_decimal(value) when is_tuple(value) do
    try do
      case tuple_size(value) do
        0 -> nil
        size when size >= 1 ->
          first_elem = elem(value, 0)
          # Check what type the first element is
          cond do
            match?(%Decimal{}, first_elem) -> first_elem  # Already a Decimal
            is_binary(first_elem) -> parse_decimal_string(first_elem)  # String
            is_number(first_elem) -> Decimal.new(first_elem)  # Number
            true -> nil
          end
      end
    rescue
      _ -> nil
    end
  end

  # Handle lists (shouldn't happen, but handle gracefully)
  def parse_decimal([value | _]) when is_binary(value), do: parse_decimal_string(value)
  def parse_decimal([_ | _]), do: nil
  def parse_decimal([]), do: nil

  # Handle binary strings
  def parse_decimal(value) when is_binary(value) do
    parse_decimal_string(value)
  end

  # Handle Decimal structs directly
  def parse_decimal(%Decimal{} = decimal), do: decimal

  # Handle numbers
  def parse_decimal(value) when is_number(value), do: Decimal.new(value)

  # Catch-all for anything else
  def parse_decimal(_), do: nil

  # Private helper to parse string values - ONLY accepts binaries
  defp parse_decimal_string(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "" do
      nil
    else
      case Decimal.parse(trimmed) do
        {:ok, decimal} -> decimal
        :error -> nil
      end
    end
  end

  # Catch-all for parse_decimal_string - should never be called with non-binary
  defp parse_decimal_string(_), do: nil

  # Helper to safely get CSV value
  def get_value(row, key, default \\ nil) do
    case Map.get(row, key) do
      nil -> default
      "" -> default
      value when is_tuple(value) ->
        # Handle unexpected tuples - extract first element if it's a string
        case value do
          {v, _} when is_binary(v) -> v
          {%Decimal{} = d, _} -> d  # Already a Decimal
          _ -> default
        end
      value -> value
    end
  end
end

# ======================
# 1. Seed Köppen Zones
# ======================

IO.puts("\n=== Seeding Köppen Climate Zones ===")
koppen_file = "priv/repo/seeds/data/koppen_climate_zones.csv"

koppen_count =
  if File.exists?(koppen_file) do
    count = koppen_file
      |> File.read!()
      |> CSV.parse_string()
      |> Enum.drop(1)  # Skip header row
      |> Enum.reduce(0, fn row, acc ->
        # Convert row list to map with headers
        headers = ["code", "name", "category", "description", "temperature_pattern", "precipitation_pattern"]
        row_map = Enum.zip(headers, row) |> Enum.into(%{})
        code = SeedHelpers.get_value(row_map, "code")

        if code do
          case Repo.get_by(KoppenZone, code: code) do
            nil ->
              %KoppenZone{}
              |> KoppenZone.changeset(%{
                code: code,
                name: SeedHelpers.get_value(row_map, "name"),
                category: SeedHelpers.get_value(row_map, "category"),
                description: SeedHelpers.get_value(row_map, "description"),
                temperature_pattern: SeedHelpers.get_value(row_map, "temperature_pattern"),
                precipitation_pattern: SeedHelpers.get_value(row_map, "precipitation_pattern")
              })
              |> Repo.insert!()

              IO.write(".")
              acc + 1

            _ ->
              acc
          end
        else
          acc
        end
      end)

    IO.puts("\n✅ Inserted #{count} Köppen zones")
    count
  else
    IO.puts("⚠️  File not found: #{koppen_file}")
    IO.puts("   Skipping Köppen zones...")
    0
  end

# ======================
# 2. Seed Cities
# ======================

IO.puts("\n=== Seeding Cities ===")
cities_file = "priv/repo/seeds/data/world_cities_climate_zones.csv"

cities_count =
  if File.exists?(cities_file) do
    count = cities_file
      |> File.read!()
      |> CSV.parse_string()
      |> Enum.drop(1)  # Skip header row
      |> Enum.reduce(0, fn row, acc ->
        headers = ["city_name", "country", "state_province_territory", "latitude", "longitude", "koppen_code", "hemisphere", "notes"]
        row_map = Enum.zip(headers, row) |> Enum.into(%{})
        city_name = SeedHelpers.get_value(row_map, "city_name")
        country = SeedHelpers.get_value(row_map, "country")

      if city_name && country do
        # Extract latitude/longitude directly from map, ensuring they're strings
        lat_raw = Map.get(row_map, "latitude")
        lon_raw = Map.get(row_map, "longitude")

        # Convert to string, handling any edge cases
        lat_str = cond do
          is_nil(lat_raw) -> nil
          lat_raw == "" -> nil
          is_binary(lat_raw) -> lat_raw
          is_tuple(lat_raw) and tuple_size(lat_raw) >= 1 ->
            case elem(lat_raw, 0) do
              v when is_binary(v) -> v
              %Decimal{} = d -> Decimal.to_string(d)
              _ -> nil
            end
          true -> nil
        end

        lon_str = cond do
          is_nil(lon_raw) -> nil
          lon_raw == "" -> nil
          is_binary(lon_raw) -> lon_raw
          is_tuple(lon_raw) and tuple_size(lon_raw) >= 1 ->
            case elem(lon_raw, 0) do
              v when is_binary(v) -> v
              %Decimal{} = d -> Decimal.to_string(d)
              _ -> nil
            end
          true -> nil
        end

        # Parse to Decimal - handle all edge cases here
        latitude = try do
          case lat_str do
            nil -> nil
            "" -> nil
            str when is_binary(str) -> SeedHelpers.parse_decimal(str)
            {%Decimal{} = dec, _} -> dec  # Already a Decimal in tuple
            {str, _} when is_binary(str) -> SeedHelpers.parse_decimal(str)  # String in tuple
            {num, _} when is_number(num) -> Decimal.new(num)  # Number in tuple
            _ -> nil
          end
        rescue
          _ -> nil
        end

        longitude = try do
          case lon_str do
            nil -> nil
            "" -> nil
            str when is_binary(str) -> SeedHelpers.parse_decimal(str)
            {%Decimal{} = dec, _} -> dec  # Already a Decimal in tuple
            {str, _} when is_binary(str) -> SeedHelpers.parse_decimal(str)  # String in tuple
            {num, _} when is_number(num) -> Decimal.new(num)  # Number in tuple
            _ -> nil
          end
        rescue
          _ -> nil
        end

        case Repo.get_by(City, city_name: city_name, country: country) do
          nil ->
            %City{}
            |> City.changeset(%{
              city_name: city_name,
              country: country,
              state_province_territory: SeedHelpers.get_value(row_map, "state_province_territory"),
              latitude: latitude,
              longitude: longitude,
              koppen_code: SeedHelpers.get_value(row_map, "koppen_code"),
              hemisphere: SeedHelpers.get_value(row_map, "hemisphere"),
              notes: SeedHelpers.get_value(row_map, "notes")
            })
            |> Repo.insert!()

            IO.write(".")
            acc + 1

          _ ->
            acc
        end
      else
        acc
      end
    end)

    IO.puts("\n✅ Inserted #{count} cities")
    count
  else
    IO.puts("⚠️  File not found: #{cities_file}")
    IO.puts("   Skipping cities...")
    0
  end

# ======================
# 3. Seed Plants
# ======================

IO.puts("\n=== Seeding Plants ===")
plants_file = "priv/repo/seeds/data/plants_database_500.csv"

plants_count =
  if File.exists?(plants_file) do
    count = plants_file
      |> File.read!()
      |> CSV.parse_string()
      |> Enum.drop(1)  # Skip header row
      |> Enum.reduce(0, fn row, acc ->
        headers = ["common_name", "scientific_name", "plant_family", "plant_type", "climate_zones", "growing_difficulty", "space_required", "sunlight_needs", "water_needs", "days_to_germination", "days_to_harvest", "perennial_annual", "planting_months_sh", "planting_months_nh", "height_cm", "spread_cm", "native_region", "description"]
        row_map = Enum.zip(headers, row) |> Enum.into(%{})
        common_name = SeedHelpers.get_value(row_map, "common_name")
        scientific_name = SeedHelpers.get_value(row_map, "scientific_name")

      if common_name do
        {germ_min, germ_max} = SeedHelpers.parse_range(SeedHelpers.get_value(row_map, "days_to_germination"))
        {harvest_min, harvest_max} = SeedHelpers.parse_range(SeedHelpers.get_value(row_map, "days_to_harvest"))
        {height_min, height_max} = SeedHelpers.parse_range(SeedHelpers.get_value(row_map, "height_cm"))
        {spread_min, spread_max} = SeedHelpers.parse_range(SeedHelpers.get_value(row_map, "spread_cm"))
        climate_zones = SeedHelpers.parse_climate_zones(SeedHelpers.get_value(row_map, "climate_zones"))

        # Check for duplicate - match by common_name and scientific_name if both exist
        existing =
          if scientific_name do
            Repo.get_by(Plant, common_name: common_name, scientific_name: scientific_name)
          else
            Repo.get_by(Plant, common_name: common_name)
          end

        case existing do
          nil ->
            %Plant{}
            |> Plant.changeset(%{
              common_name: common_name,
              scientific_name: scientific_name,
              plant_family: SeedHelpers.get_value(row_map, "plant_family"),
              plant_type: SeedHelpers.get_value(row_map, "plant_type"),
              climate_zones: climate_zones,
              growing_difficulty: SeedHelpers.get_value(row_map, "growing_difficulty"),
              space_required: SeedHelpers.get_value(row_map, "space_required"),
              sunlight_needs: SeedHelpers.get_value(row_map, "sunlight_needs"),
              water_needs: SeedHelpers.get_value(row_map, "water_needs"),
              days_to_germination_min: germ_min,
              days_to_germination_max: germ_max,
              days_to_harvest_min: harvest_min,
              days_to_harvest_max: harvest_max,
              perennial_annual: SeedHelpers.get_value(row_map, "perennial_annual"),
              planting_months_sh: SeedHelpers.get_value(row_map, "planting_months_sh"),
              planting_months_nh: SeedHelpers.get_value(row_map, "planting_months_nh"),
              height_cm_min: height_min,
              height_cm_max: height_max,
              spread_cm_min: spread_min,
              spread_cm_max: spread_max,
              native_region: SeedHelpers.get_value(row_map, "native_region"),
              description: SeedHelpers.get_value(row_map, "description")
            })
            |> Repo.insert!()

            IO.write(".")
            acc + 1

          _ ->
            acc
        end
      else
        acc
      end
    end)

    IO.puts("\n✅ Inserted #{count} plants")
    count
  else
    IO.puts("⚠️  File not found: #{plants_file}")
    IO.puts("   Skipping plants...")
    0
  end

# ======================
# 4. Seed Companion Relationships
# ======================

IO.puts("\n=== Seeding Companion Relationships ===")
companions_file = "priv/repo/seeds/data/companion_planting_relationships.csv"

companions_count =
  if File.exists?(companions_file) do
    count = companions_file
      |> File.read!()
      |> CSV.parse_string()
      |> Enum.drop(1)  # Skip header row
      |> Enum.reduce(0, fn row, acc ->
        headers = ["plant_a", "plant_b", "relationship_type", "evidence_level", "mechanism", "notes"]
        row_map = Enum.zip(headers, row) |> Enum.into(%{})
        plant_a_name = SeedHelpers.get_value(row_map, "plant_a")
        plant_b_name = SeedHelpers.get_value(row_map, "plant_b")

      if plant_a_name && plant_b_name do
        plant_a = Repo.get_by(Plant, common_name: plant_a_name)
        plant_b = Repo.get_by(Plant, common_name: plant_b_name)

        if plant_a && plant_b do
          case Repo.get_by(CompanionRelationship, plant_a_id: plant_a.id, plant_b_id: plant_b.id) do
            nil ->
              %CompanionRelationship{}
              |> CompanionRelationship.changeset(%{
                plant_a_id: plant_a.id,
                plant_b_id: plant_b.id,
                relationship_type: SeedHelpers.get_value(row_map, "relationship_type"),
                evidence_level: SeedHelpers.get_value(row_map, "evidence_level"),
                mechanism: SeedHelpers.get_value(row_map, "mechanism"),
                notes: SeedHelpers.get_value(row_map, "notes")
              })
              |> Repo.insert!()

              IO.write(".")
              acc + 1

            _ ->
              acc
          end
        else
          if !plant_a, do: Logger.warning("Plant not found: #{plant_a_name}")
          if !plant_b, do: Logger.warning("Plant not found: #{plant_b_name}")
          acc
        end
      else
        acc
      end
    end)

    IO.puts("\n✅ Inserted #{count} companion relationships")
    count
  else
    IO.puts("⚠️  File not found: #{companions_file}")
    IO.puts("   Skipping companion relationships...")
    0
  end

# ======================
# Summary
# ======================

IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("🌱 Planting Guide Database Seeding Complete!")
IO.puts(String.duplicate("=", 50))
IO.puts("Summary:")
IO.puts("  - Köppen Zones: #{koppen_count}")
IO.puts("  - Cities: #{cities_count}")
IO.puts("  - Plants: #{plants_count}")
IO.puts("  - Companion Relationships: #{companions_count}")
IO.puts(String.duplicate("=", 50) <> "\n")
