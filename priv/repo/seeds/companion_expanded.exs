# Expanded Companion Planting Relationships Seed File
#
# This script imports additional companion planting relationships from companion_planting_EXPANDED.csv
# Run with: mix run priv/repo/seeds/companion_expanded.exs
#
# Adds relationships to the existing companion_planting_relationships table (does not replace)

alias GreenManTavern.Repo
alias GreenManTavern.PlantingGuide.{Plant, CompanionRelationship}

import Ecto.Query

require Logger

# Setup NimbleCSV parser
NimbleCSV.define(CSVParser, separator: ",", escape: "\"")
alias CSVParser, as: CSV

IO.puts("Importing expanded companion planting relationships...")
IO.puts("Reading from: priv/repo/seeds/data/companion_planting_EXPANDED.csv")

csv_file = "priv/repo/seeds/data/companion_planting_EXPANDED.csv"

if !File.exists?(csv_file) do
  IO.puts("❌ ERROR: File not found: #{csv_file}")
  System.halt(1)
end

# Helper functions to map CSV values to schema values
map_relationship_type = fn
  "beneficial" -> "good"
  "incompatible" -> "bad"
  "bad" -> "bad"
  "good" -> "good"
  other -> other
end

map_evidence_level = fn
  "strong" -> "scientific"
  "moderate" -> "traditional_strong"
  "traditional" -> "traditional_weak"
  other -> other
end

# Track statistics
stats = %{
  processed: 0,
  inserted: 0,
  skipped_existing: 0,
  skipped_not_found_a: 0,
  skipped_not_found_b: 0,
  errors: 0
}

final_stats =
  csv_file
  |> File.read!()
  |> CSV.parse_string()
  |> Enum.drop(1)  # Skip header row
  |> Enum.with_index(1)
  |> Enum.reduce(stats, fn {row, idx}, acc ->
    headers = ["plant_a", "plant_b", "relationship_type", "effect_description", "evidence_tier", "notes"]
    row_map = Enum.zip(headers, row) |> Enum.into(%{})

    plant_a_name = String.trim(row_map["plant_a"] || "")
    plant_b_name = String.trim(row_map["plant_b"] || "")

    cond do
      plant_a_name == "" || plant_b_name == "" ->
        IO.puts("  ⚠ Row #{idx}: Missing plant name(s)")
        %{acc | errors: acc.errors + 1}

      true ->
        # Look up plants (case-insensitive)
        plant_a = Repo.one(
          from p in Plant,
          where: fragment("LOWER(?)", p.common_name) == ^String.downcase(plant_a_name),
          limit: 1
        )

        plant_b = Repo.one(
          from p in Plant,
          where: fragment("LOWER(?)", p.common_name) == ^String.downcase(plant_b_name),
          limit: 1
        )

        cond do
          is_nil(plant_a) ->
            IO.puts("  ⚠ Row #{idx}: Plant not found: #{plant_a_name}")
            %{acc | skipped_not_found_a: acc.skipped_not_found_a + 1, processed: acc.processed + 1}

          is_nil(plant_b) ->
            IO.puts("  ⚠ Row #{idx}: Plant not found: #{plant_b_name}")
            %{acc | skipped_not_found_b: acc.skipped_not_found_b + 1, processed: acc.processed + 1}

          true ->
            # Check if relationship already exists (either direction)
            exists = Repo.exists?(
              from cr in CompanionRelationship,
              where: (cr.plant_a_id == ^plant_a.id and cr.plant_b_id == ^plant_b.id) or
                     (cr.plant_a_id == ^plant_b.id and cr.plant_b_id == ^plant_a.id)
            )

            if exists do
              # Skip - already exists
              if rem(idx, 50) == 0 do
                IO.puts("  ✓ Processed #{idx} rows...")
              end
              %{acc | skipped_existing: acc.skipped_existing + 1, processed: acc.processed + 1}
            else
              # Map CSV fields to schema fields
              relationship_type = row_map["relationship_type"] |> String.trim() |> map_relationship_type.()
              evidence_tier = row_map["evidence_tier"] |> String.trim() |> map_evidence_level.()
              mechanism = String.trim(row_map["effect_description"] || "")
              notes = String.trim(row_map["notes"] || "")

              # Create new relationship
              case %CompanionRelationship{}
                   |> CompanionRelationship.changeset(%{
                     plant_a_id: plant_a.id,
                     plant_b_id: plant_b.id,
                     relationship_type: relationship_type,
                     evidence_level: evidence_tier,
                     mechanism: if(mechanism == "", do: nil, else: mechanism),
                     notes: if(notes == "", do: nil, else: notes)
                   })
                   |> Repo.insert() do
                {:ok, _relationship} ->
                  if rem(idx, 50) == 0 do
                    IO.puts("  ✓ Processed #{idx} rows...")
                  end
                  %{acc | inserted: acc.inserted + 1, processed: acc.processed + 1}

                {:error, changeset} ->
                  IO.puts("  ❌ Row #{idx}: Failed to insert: #{inspect(changeset.errors)}")
                  %{acc | errors: acc.errors + 1, processed: acc.processed + 1}
              end
            end
        end
    end
  end)

# Print summary
IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("✅ Companion relationships import complete!")
IO.puts(String.duplicate("=", 60))
IO.puts("Summary:")
IO.puts("  📊 Total rows processed: #{final_stats.processed}")
IO.puts("  ✅ New relationships inserted: #{final_stats.inserted}")
IO.puts("  ⏭️  Skipped (already exists): #{final_stats.skipped_existing}")
IO.puts("  ⚠️  Skipped (plant_a not found): #{final_stats.skipped_not_found_a}")
IO.puts("  ⚠️  Skipped (plant_b not found): #{final_stats.skipped_not_found_b}")
IO.puts("  ❌ Errors: #{final_stats.errors}")

total = Repo.aggregate(CompanionRelationship, :count)
IO.puts("\n  📈 Total relationships in database: #{total}")
IO.puts(String.duplicate("=", 60) <> "\n")
