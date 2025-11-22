alias GreenManTavern.Repo
alias GreenManTavern.Systems.System

IO.puts("\n=== Seeding Systems Library (Resource Types) ===\n")

# Define resource-type systems
resources = [
  # Kitchen/Food Storage
  %{
    name: "Kitchen",
    system_type: "resource",
    category: "food",
    icon_name: "utensils",
    space_required: "indoor",
    skill_level: "beginner",
    description: "Primary food preparation and usage point",
    default_inputs: ["vegetables", "herbs", "fresh-produce", "processed-food"],
    default_outputs: ["prepared-meals", "food-scraps"]
  },
  
  %{
    name: "Refrigerator",
    system_type: "resource",
    category: "food",
    icon_name: "snowflake",
    space_required: "indoor",
    skill_level: "beginner",
    description: "Cold storage for perishable foods",
    default_inputs: ["fresh-produce", "vegetables", "herbs", "dairy"],
    default_outputs: ["fresh-ingredients", "food-waste"]
  },
  
  %{
    name: "Pantry",
    system_type: "resource",
    category: "food",
    icon_name: "archive",
    space_required: "indoor",
    skill_level: "beginner",
    description: "Dry goods and preserved foods storage",
    default_inputs: ["dried-goods", "preserved-food", "grains", "legumes"],
    default_outputs: ["ingredients"]
  },
  
  %{
    name: "Spice Rack",
    system_type: "resource",
    category: "food",
    icon_name: "sparkles",
    space_required: "indoor",
    skill_level: "beginner",
    description: "Dried herbs and spices storage",
    default_inputs: ["dried-herbs", "spices"],
    default_outputs: ["seasonings"]
  },
  
  # Garden Systems
  %{
    name: "Herb Garden",
    system_type: "resource",
    category: "food",
    icon_name: "leaf",
    space_required: "indoor or outdoor",
    skill_level: "beginner",
    description: "Fresh culinary and medicinal herbs",
    default_inputs: ["water", "sunlight", "compost"],
    default_outputs: ["fresh-herbs", "plant-waste"]
  },
  
  %{
    name: "Vegetable Garden",
    system_type: "resource",
    category: "food",
    icon_name: "sprout",
    space_required: "outdoor",
    skill_level: "intermediate",
    description: "Food-producing garden beds",
    default_inputs: ["water", "sunlight", "compost", "seeds"],
    default_outputs: ["vegetables", "plant-waste", "seeds"]
  },
  
  %{
    name: "Container Garden",
    system_type: "resource",
    category: "food",
    icon_name: "flower-2",
    space_required: "balcony or patio",
    skill_level: "beginner",
    description: "Portable growing containers",
    default_inputs: ["water", "sunlight", "potting-mix"],
    default_outputs: ["vegetables", "herbs"]
  },
  
  %{
    name: "Indoor Microgreens",
    system_type: "resource",
    category: "food",
    icon_name: "seedling",
    space_required: "indoor",
    skill_level: "beginner",
    description: "Quick-growing nutritious greens",
    default_inputs: ["water", "seeds", "light"],
    default_outputs: ["microgreens"]
  },
  
  # Tools & Equipment
  %{
    name: "Garden Tools",
    system_type: "resource",
    category: "waste",
    icon_name: "wrench",
    space_required: "any",
    skill_level: "beginner",
    description: "Hand tools for gardening (trowels, spades, pruners)",
    default_inputs: [],
    default_outputs: []
  },
  
  %{
    name: "Kitchen Tools",
    system_type: "resource",
    category: "food",
    icon_name: "utensils",
    space_required: "indoor",
    skill_level: "beginner",
    description: "Cooking and food processing tools",
    default_inputs: [],
    default_outputs: []
  },
  
  # Appliances
  %{
    name: "Sous Vide",
    system_type: "resource",
    category: "food",
    icon_name: "thermometer",
    space_required: "indoor",
    skill_level: "intermediate",
    description: "Precision cooking appliance",
    default_inputs: ["raw-ingredients"],
    default_outputs: ["cooked-food"]
  },
  
  %{
    name: "Food Dehydrator",
    system_type: "resource",
    category: "food",
    icon_name: "sun",
    space_required: "indoor",
    skill_level: "beginner",
    description: "Electric food dehydrator for preserving",
    default_inputs: ["fresh-produce", "herbs"],
    default_outputs: ["dried-food", "dried-herbs"]
  },
  
  # Storage Containers
  %{
    name: "Mason Jars",
    system_type: "resource",
    category: "food",
    icon_name: "jar",
    space_required: "any",
    skill_level: "beginner",
    description: "Glass storage jars for preserving",
    default_inputs: [],
    default_outputs: []
  },
  
  %{
    name: "Storage Containers",
    system_type: "resource",
    category: "food",
    icon_name: "box",
    space_required: "any",
    skill_level: "beginner",
    description: "Food storage containers",
    default_inputs: [],
    default_outputs: []
  },
  
  # Water Systems
  %{
    name: "Rain Barrel",
    system_type: "resource",
    category: "water",
    icon_name: "droplets",
    space_required: "outdoor",
    skill_level: "intermediate",
    description: "Rainwater collection system",
    default_inputs: ["rainwater"],
    default_outputs: ["stored-water"]
  },
  
  %{
    name: "Watering Can",
    system_type: "resource",
    category: "water",
    icon_name: "droplet",
    space_required: "any",
    skill_level: "beginner",
    description: "Manual watering tool",
    default_inputs: ["water"],
    default_outputs: []
  }
]

# Insert systems with better error handling
IO.puts("Total systems to seed: #{length(resources)}\n")

{inserted, skipped, errors} = 
  Enum.reduce(resources, {0, 0, []}, fn attrs, {ins, skip, errs} ->
    case Repo.get_by(System, name: attrs.name) do
      nil ->
        try do
          %System{}
          |> System.changeset(attrs)
          |> Repo.insert!()
          IO.write("✓")
          {ins + 1, skip, errs}
        rescue
          e ->
            IO.write("✗")
            {ins, skip, [{attrs.name, Exception.message(e)} | errs]}
        end
      _ ->
        IO.write("-")
        {ins, skip + 1, errs}
    end
  end)

IO.puts("\n")
IO.puts("="<>String.duplicate("=", 50))
IO.puts("Results:")
IO.puts("  ✓ Inserted: #{inserted}")
IO.puts("  - Skipped (already exist): #{skipped}")
IO.puts("  ✗ Errors: #{length(errors)}")

if length(errors) > 0 do
  IO.puts("\nErrors encountered:")
  Enum.each(errors, fn {name, msg} ->
    IO.puts("  #{name}: #{msg}")
  end)
end

IO.puts("="<>String.duplicate("=", 50))
