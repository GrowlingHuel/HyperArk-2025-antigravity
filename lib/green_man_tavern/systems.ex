defmodule GreenManTavern.Systems do
  @moduledoc """
  The Systems context.
  """

  import Ecto.Query, warn: false
  alias GreenManTavern.Repo

  alias GreenManTavern.Systems.System
  alias GreenManTavern.Systems.Project
  alias GreenManTavern.Systems.UserSystem
  alias GreenManTavern.Systems.Connection
  alias GreenManTavern.Systems.UserConnection
  alias GreenManTavern.Diagrams

  @doc """
  Returns the list of all systems.
  """
  def list_systems do
    Repo.all(System)
  end

  @doc """
  Returns all systems ordered by category then name. No preloads.

  Matches Prompt 2: list_all_systems/0
  """
  def list_all_systems do
    from(s in System, order_by: [asc: s.category, asc: s.name])
    |> Repo.all()
  end

  @doc """
  Returns the list of systems filtered by category.
  """
  def list_systems_by_category(category) when is_binary(category) do
    from(s in System, where: s.category == ^category)
    |> Repo.all()
  end

  @doc """
  Returns a map of category => [systems]. Categories include:
  "food", "process", "storage", "water", "waste", "energy".

  Note: our schema uses "process" and "storage" as system_type, while
  the others are stored in the category field, so we compose accordingly.

  Matches Prompt 2: list_systems_by_category/0
  """
  def list_systems_by_category do
    systems = list_all_systems()

    %{
      "food" => Enum.filter(systems, &(&1.category == "food")),
      "water" => Enum.filter(systems, &(&1.category == "water")),
      "waste" => Enum.filter(systems, &(&1.category == "waste")),
      "energy" => Enum.filter(systems, &(&1.category == "energy")),
      "process" => Enum.filter(systems, &(&1.system_type == "process")),
      "storage" => Enum.filter(systems, &(&1.system_type == "storage"))
    }
  end

  @doc """
  Returns the list of systems filtered by space requirement.
  """
  def list_systems_by_space(space_type) when is_binary(space_type) do
    from(s in System, where: ilike(s.space_required, ^"%#{space_type}%"))
    |> Repo.all()
  end

  @doc """
  Returns the list of all projects.
  """
  def list_projects do
    Repo.all(Project)
  end

  @doc """
  Gets a single project.
  """
  def get_project!(id), do: Repo.get!(Project, id)

  @doc """
  Gets a single system.
  """
  def get_system!(id), do: Repo.get!(System, id)

  @doc """
  Gets a single system by name.
  """
  def get_system_by_name(name) when is_binary(name) do
    Repo.get_by(System, name: name)
  end

  @doc """
  Creates a system.
  """
  def create_system(attrs \\ %{}) do
    %System{}
    |> System.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a system.
  """
  def update_system(%System{} = system, attrs) do
    system
    |> System.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a system.
  """
  def delete_system(%System{} = system) do
    Repo.delete(system)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking system changes.
  """
  def change_system(%System{} = system, attrs \\ %{}) do
    System.changeset(system, attrs)
  end

  # UserSystem functions

  @doc """
  Returns the list of user systems for a given user.
  """
  def list_user_systems(user_id) when is_integer(user_id) do
    from(us in UserSystem,
      where: us.user_id == ^user_id,
      preload: [:system]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of active user systems for a given user.
  """
  def list_active_user_systems(user_id) when is_integer(user_id) do
    from(us in UserSystem,
      where: us.user_id == ^user_id and us.status == "active",
      preload: [:system]
    )
    |> Repo.all()
  end

  @doc """
  Returns user's systems (active or planned) with position and notes.

  Includes joined system details. Security: filtered by user_id.

  Matches Prompt 2: get_user_systems/1
  """
  def get_user_systems(user_id) when is_integer(user_id) do
    from(us in UserSystem,
      where: us.user_id == ^user_id and us.status in ["active", "planned"],
      join: s in System,
      on: s.id == us.system_id,
      preload: [system: s],
      select: us
    )
    |> Repo.all()
  end

  @doc """
  Returns user's connections (active and potential) with from/to systems.

  Security: filtered by user_id.

  Matches Prompt 2: get_user_connections/1
  """
  def get_user_connections(user_id) when is_integer(user_id) do
    from(uc in UserConnection,
      where: uc.user_id == ^user_id and uc.status in ["active", "potential", "planned"],
      join: c in assoc(uc, :connection),
      left_join: fs in assoc(c, :from_system),
      left_join: ts in assoc(c, :to_system),
      preload: [connection: {c, from_system: fs, to_system: ts}]
    )
    |> Repo.all()
  end

  @doc """
  Creates a user_system at a position, with planned status.

  Matches Prompt 2: add_user_system/5
  """
  def add_user_system(user_id, system_id, x, y)
      when is_integer(user_id) and is_integer(system_id) and is_integer(x) and is_integer(y) do
    %UserSystem{}
    |> UserSystem.changeset(%{
      user_id: user_id,
      system_id: system_id,
      position_x: x,
      position_y: y,
      status: "planned",
      implemented_at: nil
    })
    |> Repo.insert()
  end

  @doc """
  Updates the position of an existing user_system.

  Matches Prompt 2: update_system_position/3
  """
  def update_system_position(user_system_id, x, y)
      when is_integer(user_system_id) and is_integer(x) and is_integer(y) do
    with %UserSystem{} = us <- Repo.get(UserSystem, user_system_id) do
      us
      |> UserSystem.changeset(%{position_x: x, position_y: y})
      |> Repo.update()
    else
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Deletes a user_system owned by the given user_id and cascades related
  user_connections for connections that involve the deleted system.

  Matches Prompt 2: delete_user_system/2
  """
  def delete_user_system(user_system_id, user_id)
      when is_integer(user_system_id) and is_integer(user_id) do
    case Repo.get(UserSystem, user_system_id) do
      %UserSystem{user_id: ^user_id, system_id: system_id} = us ->
        # Delete user_connections that reference connections involving this system
        from(uc in UserConnection,
          where: uc.user_id == ^user_id,
          join: c in Connection,
          on: c.id == uc.connection_id,
          where: c.from_system_id == ^system_id or c.to_system_id == ^system_id
        )
        |> Repo.delete_all()

        Repo.delete(us)

      %UserSystem{} ->
        {:error, :unauthorized}

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Gets a single user system.
  """
  def get_user_system!(id), do: Repo.get!(UserSystem, id)

  @doc """
  Gets a user system by user and system IDs.
  """
  def get_user_system_by_user_and_system(user_id, system_id)
      when is_integer(user_id) and is_integer(system_id) do
    Repo.get_by(UserSystem, user_id: user_id, system_id: system_id)
  end

  @doc """
  Creates a user system.
  """
  def create_user_system(attrs \\ %{}) do
    %UserSystem{}
    |> UserSystem.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user system.
  """
  def update_user_system(%UserSystem{} = user_system, attrs) do
    user_system
    |> UserSystem.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user system.
  """
  def delete_user_system(%UserSystem{} = user_system) do
    Repo.delete(user_system)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user system changes.
  """
  def change_user_system(%UserSystem{} = user_system, attrs \\ %{}) do
    UserSystem.changeset(user_system, attrs)
  end

  @doc """
  Groups systems by category for display.
  """
  def group_systems_by_category(systems) do
    systems
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {category, systems} ->
      {category, Enum.sort_by(systems, & &1.name)}
    end)
    |> Enum.sort_by(fn {category, _} -> category end)
  end

  @doc """
  Filters systems by user's space type.
  """
  def filter_systems_by_space(systems, user_space_type) when is_binary(user_space_type) do
    Enum.filter(systems, fn system ->
      String.contains?(system.space_required, user_space_type)
    end)
  end

  @doc """
  Gets category display name and color.
  """
  def get_category_info(category) do
    case category do
      "food" -> {"Food Production", "#CCCCCC"}
      "water" -> {"Water Systems", "#BBBBBB"}
      "waste" -> {"Waste Cycling", "#AAAAAA"}
      "energy" -> {"Energy Systems", "#999999"}
      _ -> {String.capitalize(category), "#DDDDDD"}
    end
  end

  @doc """
  Creates a connection between two systems.
  """
  def create_connection(attrs \\ %{}) do
    %Connection{}
    |> Connection.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a user connection.
  """
  def create_user_connection(attrs \\ %{}) do
    %UserConnection{}
    |> UserConnection.changeset(attrs)
    |> Repo.insert()
  end

  # ============================================================================
  # COMPOSITE SYSTEM FUNCTIONS
  # ============================================================================

  @doc """
  Creates a composite system from selected nodes and edges.

  TODO: Implementation steps:
  1. Get the selected nodes and edges from the canvas
  2. Calculate bounding box (min/max x, y) of selected nodes
  3. Create new System record with is_composite: true
  4. Store internal structure (nodes, edges) in user_systems.internal_nodes and internal_edges
  5. Remove original nodes from canvas (or mark them as hidden)
  6. Create UserSystem record for the composite node at center of bounding box
  7. Return the new composite system

  Returns {:ok, user_system} or {:error, changeset}
  """
  def create_composite_system(user_id, name, node_ids, edge_ids) do
    require Logger

    Logger.info("[Systems.create_composite_system] Starting - user_id: #{user_id}, name: #{name}, node_ids: #{inspect(node_ids)}, edge_ids: #{inspect(edge_ids)}")

    # Validate inputs
    if length(node_ids) < 2 do
      Logger.error("[Systems.create_composite_system] Not enough nodes: #{length(node_ids)}")
      {:error, :not_enough_nodes}
    else
      # Get diagram for user
      case Diagrams.get_or_create_diagram(user_id) do
        {:ok, diagram} ->
          Logger.info("[Systems.create_composite_system] Got diagram: #{diagram.id}")

          # Get nodes from diagram
          nodes = diagram.nodes || %{}
          edges = diagram.edges || %{}

          # Extract selected nodes
          selected_nodes =
            node_ids
            |> Enum.filter(&Map.has_key?(nodes, &1))
            |> Enum.map(fn node_id -> {node_id, Map.get(nodes, node_id)} end)

          Logger.info("[Systems.create_composite_system] Found #{length(selected_nodes)} nodes in diagram")

          if length(selected_nodes) < 2 do
            Logger.error("[Systems.create_composite_system] Not enough nodes found in diagram")
            {:error, :nodes_not_found}
          else
            # Calculate bounding box (center point)
            positions = Enum.map(selected_nodes, fn {_id, node_data} ->
              {Map.get(node_data, "x") || 0, Map.get(node_data, "y") || 0}
            end)

            {xs, ys} = Enum.unzip(positions)
            center_x = round(Enum.sum(xs) / length(xs))
            center_y = round(Enum.sum(ys) / length(ys))

            Logger.info("[Systems.create_composite_system] Center calculated: (#{center_x}, #{center_y})")

            # Create the composite system record
            {:ok, system} = %System{}
              |> System.changeset(%{
                name: name,
                is_composite: true,
                system_type: "process",  # Default for composite systems
                category: "food",  # Default, could be determined from components
                description: "Composite system with #{length(selected_nodes)} components"
              })
              |> Repo.insert()

            Logger.info("[Systems.create_composite_system] Created System: #{system.id}")

            # Store internal structure (nodes with relative positions)
            # We'll store the full node data with relative positions for later restoration
            internal_nodes_with_relative = Enum.map(selected_nodes, fn {node_id, node_data} ->
              x = Map.get(node_data, "x") || 0
              y = Map.get(node_data, "y") || 0

              # Store relative position in the node data and return as {id, data} tuple
              {node_id, node_data
              |> Map.put("relative_position", %{"x" => x - center_x, "y" => y - center_y})}
            end)

            # Store internal edges
            internal_edges = Enum.map(edge_ids, fn edge_id ->
              case Map.get(edges, edge_id) do
                nil -> nil
                edge_data -> %{"id" => edge_id, "data" => edge_data}
              end
            end)
            |> Enum.reject(&is_nil/1)

            # Store internal nodes data as a map keyed by original node IDs
            # internal_nodes_with_relative is a list of {node_id, node_data} tuples
            internal_nodes_map = Enum.reduce(internal_nodes_with_relative, %{}, fn {node_id, node_data}, acc ->
              Map.put(acc, node_id, node_data)
            end)

            # Store internal edges data as a map keyed by original edge IDs
            internal_edges_map = Enum.reduce(edge_ids, %{}, fn edge_id, acc ->
              case Map.get(edges, edge_id) do
                nil -> acc
                edge_data -> Map.put(acc, edge_id, edge_data)
              end
            end)

            # Create UserSystem for the composite (but note: this is for the NEW approach)
            # For now, we'll create a CompositeSystem record instead since that's the existing pattern
            # TODO: Update to use UserSystem once we migrate fully
            {:ok, composite_system} = Diagrams.create_composite_system(%{
              user_id: user_id,
              name: name,
              description: "Composite system with #{length(selected_nodes)} components",
              internal_node_ids: node_ids,
              internal_edge_ids: edge_ids,
              internal_nodes_data: internal_nodes_map,
              internal_edges_data: internal_edges_map,
              parent_diagram_id: diagram.id
            })

            Logger.info("[Systems.create_composite_system] Created CompositeSystem: #{composite_system.id}")

            # Remove original nodes from diagram
            updated_nodes = Map.drop(nodes, node_ids)

            # Remove original edges from diagram
            updated_edges = Map.drop(edges, edge_ids)

            # Add composite node to diagram
            composite_node_id = Diagrams.generate_composite_node_id(composite_system.id)
            composite_node_data = %{
              "composite_system_id" => composite_system.id,
              "x" => center_x,
              "y" => center_y,
              "is_expanded" => false,
              "name" => name
            }

            updated_nodes = Map.put(updated_nodes, composite_node_id, composite_node_data)

            # Update diagram
            case Diagrams.update_diagram(diagram, %{nodes: updated_nodes, edges: updated_edges}) do
              {:ok, _updated_diagram} ->
                Logger.info("[Systems.create_composite_system] Diagram updated successfully")
                {:ok, composite_system}

              {:error, changeset} ->
                Logger.error("[Systems.create_composite_system] Failed to update diagram: #{inspect(changeset.errors)}")
                # Rollback: delete the composite system we just created
                Repo.delete(composite_system)
                Repo.delete(system)
                {:error, changeset}

              other ->
                Logger.error("[Systems.create_composite_system] Unexpected error updating diagram: #{inspect(other)}")
                # Rollback
                Repo.delete(composite_system)
                Repo.delete(system)
                {:error, :update_failed}
            end
          end

        {:error, changeset} ->
          Logger.error("[Systems.create_composite_system] Failed to get/create diagram: #{inspect(changeset.errors)}")
          {:error, changeset}

        other ->
          Logger.error("[Systems.create_composite_system] Unexpected error getting diagram: #{inspect(other)}")
          {:error, :diagram_error}
      end
    end
  end

  @doc """
  Expands a composite system to show its internal components.

  TODO: Implementation steps:
  1. Get composite UserSystem record
  2. Verify is_expanded is currently false
  3. Load internal_nodes and internal_edges from user_systems
  4. Update is_expanded: true
  5. Return child nodes and edges to render on canvas

  Returns {:ok, %{nodes: [...], edges: [...]}} or {:error, reason}
  """
  def expand_composite_system(user_system_id) do
    # TODO: Implement expansion logic
    # - Fetch UserSystem with preloaded system
    # - Verify system.is_composite == true
    # - Load internal_nodes and internal_edges
    # - Update is_expanded: true
    # - Transform internal data back to canvas format
    # - Return nodes and edges for rendering
    {:error, :not_implemented}
  end

  @doc """
  Collapses a composite system back to a single node.

  TODO: Implementation steps:
  1. Get composite UserSystem record
  2. Verify is_expanded is currently true
  3. Remove child nodes from canvas
  4. Update is_expanded: false
  5. Return success

  Returns {:ok, user_system} or {:error, reason}
  """
  def collapse_composite_system(user_system_id) do
    # TODO: Implement collapse logic
    # - Fetch UserSystem
    # - Verify system.is_composite == true and is_expanded == true
    # - Remove child nodes from canvas
    # - Update is_expanded: false
    # - Return updated user_system
    {:error, :not_implemented}
  end
end
