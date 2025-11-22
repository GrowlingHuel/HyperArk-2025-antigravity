# Plant Quest Test Seed Data
#
# NOTE: This seed file requires the plant quest migration to be run first.
# Run: mix ecto.migrate
# The migration should add: quest_type, plant_tracking, date_window_start,
# date_window_end, planting_complete, harvest_complete columns to user_quests table.
#
import Ecto.Query
alias GreenManTavern.Repo
alias GreenManTavern.Accounts.User
alias GreenManTavern.PlantingGuide
alias GreenManTavern.PlantingGuide.{Plant, UserPlant}
alias GreenManTavern.Quests
alias GreenManTavern.Quests.UserQuest
import Ecto.Changeset
import Bcrypt, only: [hash_pwd_salt: 1]

require Logger

IO.puts("\n🌱 Plant Quest Test Seed Data")
IO.puts("=" |> String.duplicate(60))

# Get or create a test user
user = Repo.get_by(User, email: "jesse@testuser.com") ||
       Repo.insert!(%User{
         email: "jesse@testuser.com",
         hashed_password: hash_pwd_salt("password123"),
         confirmed_at: DateTime.utc_today()
       })

IO.puts("Using user: #{user.email} (ID: #{user.id})")

# Delete existing test data (idempotent)
IO.puts("\nCleaning up existing test data...")

# Find plant IDs first
plant_ids = Repo.all(
  from(p in Plant,
    where: p.common_name in ["Tomato", "Basil", "Lettuce", "Carrot"],
    select: p.id
  )
)

# Delete user_plants for test plants
if plant_ids != [] do
  {count, _} = Repo.delete_all(
    from(up in UserPlant,
      where: up.user_id == ^user.id,
      where: up.plant_id in ^plant_ids
    )
  )
  IO.puts("  Deleted #{count} user plants")
end

# Delete planting quests for this user
# Delete all quests for this user (we'll recreate them)
{quest_count, _} = Repo.delete_all(
  from(uq in UserQuest, where: uq.user_id == ^user.id)
)
IO.puts("  Deleted #{quest_count} user quests")

IO.puts("✓ Cleaned up existing test data")

# Find or get plants
IO.puts("\nFinding plants...")

tomato = Repo.get_by(Plant, common_name: "Tomato") ||
         Repo.one(from(p in Plant, where: ilike(p.common_name, "%tomato%"), limit: 1))

basil = Repo.get_by(Plant, common_name: "Basil") ||
        Repo.one(from(p in Plant, where: ilike(p.common_name, "%basil%"), limit: 1))

lettuce = Repo.get_by(Plant, common_name: "Lettuce") ||
          Repo.one(from(p in Plant, where: ilike(p.common_name, "%lettuce%"), limit: 1))

carrot = Repo.get_by(Plant, common_name: "Carrot") ||
         Repo.one(from(p in Plant, where: ilike(p.common_name, "%carrot%"), limit: 1))

unless tomato && basil && lettuce && carrot do
  IO.puts("⚠️  Warning: Could not find all required plants!")
  IO.puts("  Tomato: #{if tomato, do: "✓", else: "✗"}")
  IO.puts("  Basil: #{if basil, do: "✓", else: "✗"}")
  IO.puts("  Lettuce: #{if lettuce, do: "✓", else: "✗"}")
  IO.puts("  Carrot: #{if carrot, do: "✓", else: "✗"}")
  IO.puts("\nPlease ensure plants are seeded first (run planting_guide_seeds.exs)")
  System.halt(1)
end

IO.puts("✓ Found all plants")

# Define test dates (using 2025 for consistency)
today = Date.utc_today()
year = today.year

nov_10 = Date.new!(year, 11, 10)
nov_15 = Date.new!(year, 11, 15)
nov_16 = Date.new!(year, 11, 16)
nov_25 = Date.new!(year, 11, 25)
dec_5 = Date.new!(year, 12, 5)

# Get a city (or create a default one)
city = Repo.one(from(c in PlantingGuide.City, limit: 1)) ||
       Repo.insert!(%PlantingGuide.City{
         city_name: "Test City",
         country: "Test Country",
         koppen_code: "Cfb",
         hemisphere: "Northern",
         latitude: 45.0,
         longitude: -75.0
       })

IO.puts("\nCreating user plants...")

# 1. Tomato - will_plant, Nov 15
tomato_plant = Repo.insert!(%UserPlant{
  user_id: user.id,
  plant_id: tomato.id,
  city_id: city.id,
  status: "will_plant",
  planting_date_start: nov_15,
  planting_date_end: nov_15,
  planting_method: "seeds"
})
IO.puts("  ✓ Tomato (will_plant, Nov 15) - ID: #{tomato_plant.id}")

# 2. Basil - have_planted, Nov 16, planted Nov 16
basil_plant = Repo.insert!(%UserPlant{
  user_id: user.id,
  plant_id: basil.id,
  city_id: city.id,
  status: "planted",
  planting_date_start: nov_16,
  planting_date_end: nov_16,
  actual_planting_date: nov_16,
  planting_method: "seedlings"
})
IO.puts("  ✓ Basil (have_planted, Nov 16) - ID: #{basil_plant.id}")

# 3. Lettuce - have_harvested, Nov 10, planted Nov 10, harvested Dec 5
lettuce_plant = Repo.insert!(%UserPlant{
  user_id: user.id,
  plant_id: lettuce.id,
  city_id: city.id,
  status: "harvested",
  planting_date_start: nov_10,
  planting_date_end: nov_10,
  actual_planting_date: nov_10,
  actual_harvest_date: dec_5,
  planting_method: "seeds"
})
IO.puts("  ✓ Lettuce (have_harvested, Nov 10 → Dec 5) - ID: #{lettuce_plant.id}")

# 4. Carrot - will_plant, Nov 25 (outside 7 day window)
carrot_plant = Repo.insert!(%UserPlant{
  user_id: user.id,
  plant_id: carrot.id,
  city_id: city.id,
  status: "will_plant",
  planting_date_start: nov_25,
  planting_date_end: nov_25,
  planting_method: "seeds"
})
IO.puts("  ✓ Carrot (will_plant, Nov 25) - ID: #{carrot_plant.id}")

IO.puts("\nCreating planting quests...")

# Quest 1: Multiple plants on same date (Nov 15)
# This should group Tomato with any other plants on Nov 15
# For testing, we'll create a quest with Tomato only (since it's the only one on Nov 15)
IO.puts("\n1. Creating quest: Multiple plants on same date (Nov 15)")

tomato_entry = %{
  "plant_id" => tomato_plant.id,
  "variety_name" => tomato.common_name,
  "status" => "will_plant",
  "planting_date" => Date.to_string(nov_15),
  "expected_harvest" => if(tomato.days_to_harvest_max, do: Date.to_string(Date.add(nov_15, tomato.days_to_harvest_max)), else: nil),
  "actual_planting_date" => nil,
  "actual_harvest_date" => nil
}

quest1 = Repo.insert!(%UserQuest{
  user_id: user.id,
  status: "available",
  title: "Plant Tomatoes on November 15",
  description: "Plant tomatoes in your garden on November 15th.",
  objective: "Plant all scheduled tomatoes on November 15, 2025",
  steps: %{"steps" => [
    %{"text" => "Prepare planting area for tomatoes", "completed" => false},
    %{"text" => "Plant #{tomato.common_name}", "plant_id" => tomato_plant.id, "completed" => false}
  ]},
  plant_tracking: %{"steps" => [tomato_entry]},
  date_window_start: nov_15,
  date_window_end: nov_15,
  planting_complete: false,
  harvest_complete: false
})
IO.puts("   ✓ Quest ID: #{quest1.id} - Status: #{quest1.status}")

# Quest 2: Plants in date range (Nov 15-16)
# This should group Tomato and Basil together
IO.puts("\n2. Creating quest: Plants in date range (Nov 15-16)")

basil_entry = %{
  "plant_id" => basil_plant.id,
  "variety_name" => basil.common_name,
  "status" => "have_planted",
  "planting_date" => Date.to_string(nov_16),
  "expected_harvest" => if(basil.days_to_harvest_max, do: Date.to_string(Date.add(nov_16, basil.days_to_harvest_max)), else: nil),
  "actual_planting_date" => Date.to_string(nov_16),
  "actual_harvest_date" => nil
}

# Create a combined quest with Tomato and Basil
tomato_basil_entries = [tomato_entry, basil_entry]

quest2 = Repo.insert!(%UserQuest{
  user_id: user.id,
  status: "active",  # Partially completed (Basil planted, Tomato not)
  title: "Plant Tomatoes and Basil (Nov 15-16)",
  description: "Plant tomatoes and basil in your garden between November 15-16.",
  objective: "Plant tomatoes on Nov 15 and basil on Nov 16",
  steps: %{"steps" => [
    %{"text" => "Prepare planting area", "completed" => false},
    %{"text" => "Plant #{tomato.common_name}", "plant_id" => tomato_plant.id, "completed" => false},
    %{"text" => "Plant #{basil.common_name}", "plant_id" => basil_plant.id, "completed" => true}
  ]},
  plant_tracking: %{"steps" => tomato_basil_entries},
  date_window_start: nov_15,
  date_window_end: nov_16,
  planting_complete: false,  # Not all planted yet
  harvest_complete: false
})
IO.puts("   ✓ Quest ID: #{quest2.id} - Status: #{quest2.status} (partially completed)")

# Quest 3: Fully completed quest (all harvested)
# Lettuce was planted Nov 10 and harvested Dec 5
IO.puts("\n3. Creating quest: Fully completed quest (all harvested)")

lettuce_entry = %{
  "plant_id" => lettuce_plant.id,
  "variety_name" => lettuce.common_name,
  "status" => "have_harvested",
  "planting_date" => Date.to_string(nov_10),
  "expected_harvest" => if(lettuce.days_to_harvest_max, do: Date.to_string(Date.add(nov_10, lettuce.days_to_harvest_max)), else: nil),
  "actual_planting_date" => Date.to_string(nov_10),
  "actual_harvest_date" => Date.to_string(dec_5)
}

quest3 = Repo.insert!(%UserQuest{
  user_id: user.id,
  status: "completed",
  title: "Harvest Lettuce (Completed)",
  description: "Plant and harvest lettuce in your garden.",
  objective: "Plant lettuce on Nov 10 and harvest when ready",
  steps: %{"steps" => [
    %{"text" => "Prepare planting area", "completed" => true},
    %{"text" => "Plant #{lettuce.common_name}", "plant_id" => lettuce_plant.id, "completed" => true},
    %{"text" => "Harvest #{lettuce.common_name}", "completed" => true}
  ]},
  plant_tracking: %{"steps" => [lettuce_entry]},
  date_window_start: nov_10,
  date_window_end: nov_10,
  planting_complete: true,
  harvest_complete: true
})
IO.puts("   ✓ Quest ID: #{quest3.id} - Status: #{quest3.status} (fully completed)")

# Quest 4: Partially completed quest (some planted, some not)
# This will be a quest with multiple plants where some are planted and some aren't
IO.puts("\n4. Creating quest: Partially completed (some planted, some not)")

# Create another tomato plant for this quest (different date to avoid conflicts)
tomato2_plant = Repo.insert!(%UserPlant{
  user_id: user.id,
  plant_id: tomato.id,
  city_id: city.id,
  status: "will_plant",
  planting_date_start: nov_16,
  planting_date_end: nov_16,
  planting_method: "seeds"
})

tomato2_entry = %{
  "plant_id" => tomato2_plant.id,
  "variety_name" => tomato.common_name,
  "status" => "will_plant",
  "planting_date" => Date.to_string(nov_16),
  "expected_harvest" => if(tomato.days_to_harvest_max, do: Date.to_string(Date.add(nov_16, tomato.days_to_harvest_max)), else: nil),
  "actual_planting_date" => nil,
  "actual_harvest_date" => nil
}

# Quest with Basil (planted) and Tomato2 (not planted)
partial_entries = [basil_entry, tomato2_entry]

quest4 = Repo.insert!(%UserQuest{
  user_id: user.id,
  status: "active",
  title: "Plant Basil and Tomato (Partially Complete)",
  description: "Plant basil and tomato in your garden. Basil is already planted.",
  objective: "Plant both basil and tomato on Nov 16",
  steps: %{"steps" => [
    %{"text" => "Prepare planting area", "completed" => true},
    %{"text" => "Plant #{basil.common_name}", "plant_id" => basil_plant.id, "completed" => true},
    %{"text" => "Plant #{tomato.common_name}", "plant_id" => tomato2_plant.id, "completed" => false}
  ]},
  plant_tracking: %{"steps" => partial_entries},
  date_window_start: nov_16,
  date_window_end: nov_16,
  planting_complete: false,  # Not all planted
  harvest_complete: false
})
IO.puts("   ✓ Quest ID: #{quest4.id} - Status: #{quest4.status} (1/2 planted)")

# Quest 5: Carrot on Nov 25 (outside 7 day window - separate quest)
IO.puts("\n5. Creating quest: Carrot on Nov 25 (outside window)")

carrot_entry = %{
  "plant_id" => carrot_plant.id,
  "variety_name" => carrot.common_name,
  "status" => "will_plant",
  "planting_date" => Date.to_string(nov_25),
  "expected_harvest" => if(carrot.days_to_harvest_max, do: Date.to_string(Date.add(nov_25, carrot.days_to_harvest_max)), else: nil),
  "actual_planting_date" => nil,
  "actual_harvest_date" => nil
}

quest5 = Repo.insert!(%UserQuest{
  user_id: user.id,
  status: "available",
  title: "Plant Carrots on November 25",
  description: "Plant carrots in your garden on November 25th.",
  objective: "Plant carrots on November 25, 2025",
  steps: %{"steps" => [
    %{"text" => "Prepare planting area for carrots", "completed" => false},
    %{"text" => "Plant #{carrot.common_name}", "plant_id" => carrot_plant.id, "completed" => false}
  ]},
  plant_tracking: %{"steps" => [carrot_entry]},
  date_window_start: nov_25,
  date_window_end: nov_25,
  planting_complete: false,
  harvest_complete: false
})
IO.puts("   ✓ Quest ID: #{quest5.id} - Status: #{quest5.status}")

IO.puts("\n" <> "=" |> String.duplicate(60))
IO.puts("✓ Plant quest seed data created successfully!")
IO.puts("\nSummary:")
IO.puts("  • User Plants: 5 (Tomato x2, Basil, Lettuce, Carrot)")
IO.puts("  • Planting Quests: 5")
IO.puts("    - Quest 1: Single plant on same date (Nov 15)")
IO.puts("    - Quest 2: Multiple plants in date range (Nov 15-16) - Partially complete")
IO.puts("    - Quest 3: Fully completed quest (Lettuce harvested)")
IO.puts("    - Quest 4: Partially completed (1/2 planted)")
IO.puts("    - Quest 5: Separate quest outside window (Nov 25)")
IO.puts("\nTest scenarios ready!")
