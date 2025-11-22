# Missing Companion Plants Seed File
#
# This script imports missing companion plants from missing_companion_plants.csv
# Run with: mix run priv/repo/seeds/missing_plants.exs
#
# Adds plants that are referenced in companion relationships but missing from the plants table

alias GreenManTavern.Repo
alias GreenManTavern.PlantingGuide.Plant

import Ecto.Query

require Logger

# Setup NimbleCSV parser
NimbleCSV.define(CSVParser, separator: ",", escape: "\"")
alias CSVParser, as: CSV

IO.puts("Importing missing companion plants...")
IO.puts("Reading from: priv/repo/seeds/data/missing_companion_plants.csv")

csv_file = "priv/repo/seeds/data/missing_companion_plants.csv"

if !File.exists?(csv_file) do
  IO.puts("❌ ERROR: File not found: #{csv_file}")
  System.halt(1)
end

# Helper function to safely convert string to integer
to_int = fn
  "" -> nil
  nil -> nil
  val when is_binary(val) ->
    case Integer.parse(String.trim(val)) do
      {num, _} -> num
      :error -> nil
    end
  _ -> nil
end

# Helper function to convert string boolean to actual boolean
to_bool = fn
  "true" -> true
  "false" -> false
  "True" -> true
  "False" -> false
  _ -> false
end

# Track statistics
stats = %{
  inserted: 0,
  skipped: 0
}

final_stats =
  csv_file
  |> File.read!()
  |> CSV.parse_string()
  |> Enum.drop(1)  # Skip header row
  |> Enum.reduce(stats, fn row, acc ->
    headers = [
      "common_name", "scientific_name", "plant_family", "plant_type", "climate_zones",
      "growing_difficulty", "space_required", "sunlight_needs", "water_needs",
      "days_to_germination_min", "days_to_germination_max", "days_to_harvest_min",
      "days_to_harvest_max", "perennial_annual", "planting_months_sh", "planting_months_nh",
      "height_cm_min", "height_cm_max", "spread_cm_min", "spread_cm_max",
      "native_region", "description", "transplant_friendly", "typical_seedling_age_days",
      "direct_sow_only", "seedling_difficulty", "transplant_notes"
    ]
    row_map = Enum.zip(headers, row) |> Enum.into(%{})

    common_name = String.trim(row_map["common_name"] || "")

    if common_name == "" do
      IO.puts("  ⚠️  Skipping row with empty common_name")
      acc
    else
      # Check if plant already exists (case-insensitive)
      exists = Repo.exists?(
        from p in Plant,
        where: fragment("LOWER(?)", p.common_name) == ^String.downcase(common_name)
      )

      if exists do
        IO.puts("  ⏭️  Skipping #{common_name} - already exists")
        %{acc | skipped: acc.skipped + 1}
      else
        # Parse climate zones from comma-separated string to array
        climate_zones_str = String.trim(row_map["climate_zones"] || "")
        climate_zones =
          if climate_zones_str == "" do
            []
          else
            climate_zones_str
            |> String.split(",")
            |> Enum.map(&String.trim/1)
            |> Enum.reject(&(&1 == ""))
          end

        # Convert string booleans to actual booleans
        transplant_friendly_str = String.trim(row_map["transplant_friendly"] || "true")
        direct_sow_only_str = String.trim(row_map["direct_sow_only"] || "false")
        transplant_friendly = to_bool.(transplant_friendly_str)
        direct_sow_only = to_bool.(direct_sow_only_str)

        # Create plant
        case %Plant{}
             |> Plant.changeset(%{
               common_name: common_name,
               scientific_name: String.trim(row_map["scientific_name"] || ""),
               plant_family: String.trim(row_map["plant_family"] || ""),
               plant_type: String.trim(row_map["plant_type"] || ""),
               climate_zones: climate_zones,
               growing_difficulty: String.trim(row_map["growing_difficulty"] || ""),
               space_required: String.trim(row_map["space_required"] || ""),
               sunlight_needs: String.trim(row_map["sunlight_needs"] || ""),
               water_needs: String.trim(row_map["water_needs"] || ""),
               days_to_germination_min: to_int.(row_map["days_to_germination_min"]),
               days_to_germination_max: to_int.(row_map["days_to_germination_max"]),
               days_to_harvest_min: to_int.(row_map["days_to_harvest_min"]),
               days_to_harvest_max: to_int.(row_map["days_to_harvest_max"]),
               perennial_annual: String.trim(row_map["perennial_annual"] || ""),
               planting_months_sh: String.trim(row_map["planting_months_sh"] || ""),
               planting_months_nh: String.trim(row_map["planting_months_nh"] || ""),
               height_cm_min: to_int.(row_map["height_cm_min"]),
               height_cm_max: to_int.(row_map["height_cm_max"]),
               spread_cm_min: to_int.(row_map["spread_cm_min"]),
               spread_cm_max: to_int.(row_map["spread_cm_max"]),
               native_region: String.trim(row_map["native_region"] || ""),
               description: String.trim(row_map["description"] || ""),
               transplant_friendly: transplant_friendly,
               typical_seedling_age_days: to_int.(row_map["typical_seedling_age_days"]),
               direct_sow_only: direct_sow_only,
               seedling_difficulty: String.trim(row_map["seedling_difficulty"] || ""),
               transplant_notes: String.trim(row_map["transplant_notes"] || "")
             })
             |> Repo.insert() do
          {:ok, _plant} ->
            IO.puts("  ✅ Inserted: #{common_name}")
            %{acc | inserted: acc.inserted + 1}

          {:error, changeset} ->
            IO.puts("  ❌ Failed to insert #{common_name}: #{inspect(changeset.errors)}")
            acc
        end
      end
    end
  end)

# Print summary
IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("✅ Missing plants import complete!")
IO.puts(String.duplicate("=", 60))
IO.puts("Summary:")
IO.puts("  ✅ New plants inserted: #{final_stats.inserted}")
IO.puts("  ⏭️  Skipped (already exists): #{final_stats.skipped}")
IO.puts("\n  📈 Total plants in database: #{Repo.aggregate(Plant, :count)}")
IO.puts(String.duplicate("=", 60) <> "\n")
