# Setup Test Data for Harvest Flow
alias GreenManTavern.{Repo, PlantingGuide, Diagrams}

user_id = 1

# Get basil plant (using basil since tomato is taken)
basil = PlantingGuide.list_plants() |> Enum.find(&(&1.common_name == "Basil"))

# Create or get user_plant
user_plant = case PlantingGuide.get_user_plant(user_id, basil.id) do
  nil ->
    {:ok, up} = PlantingGuide.create_user_plant(%{
      user_id: user_id,
      plant_id: basil.id,
      city_id: 1,
      planted_date: ~D[2024-11-01],
      planting_method: "seeds",
      status: "planted",
      living_web_node_id: "test_basil_node_1"
    })
    up
  existing ->
    {:ok, updated} = PlantingGuide.update_user_plant(existing, %{living_web_node_id: "test_basil_node_1"})
    updated
end

IO.puts("✅ User Plant ID: #{user_plant.id}")

# Get diagram
{:ok, diagram} = Diagrams.get_or_create_diagram(user_id)

# Add node
nodes = diagram.nodes || %{}
test_node = %{
  "id" => "test_basil_node_1",
  "type" => "resource",
  "data" => %{
    "label" => "Basil Garden",
    "linked_type" => "user_plant",
    "linked_id" => user_plant.id
  },
  "position" => %{"x" => 250, "y" => 250}
}

updated_nodes = Map.put(nodes, "test_basil_node_1", test_node)
{:ok, _diagram} = Diagrams.update_diagram(diagram, %{nodes: updated_nodes})

IO.puts("✅ Node added to diagram")
IO.puts("\n🎉 SUCCESS!")
IO.puts("User Plant ID: #{user_plant.id}")
IO.puts("Plant: Basil")
IO.puts("Node ID: test_basil_node_1")
