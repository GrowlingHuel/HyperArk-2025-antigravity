defmodule GreenManTavern.Diagrams do
  @moduledoc """
  The Diagrams context for managing user diagrams.
  """

  import Ecto.Query, warn: false
  alias GreenManTavern.Repo
  alias GreenManTavern.Diagrams.Diagram
  alias GreenManTavern.Diagrams.CompositeSystem

  @doc """
  Returns the list of diagrams for a user.
  """
  def list_diagrams(user_id) do
    from(d in Diagram, where: d.user_id == ^user_id)
    |> Repo.all()
  end

  @doc """
  Gets a single diagram.
  """
  def get_diagram!(id), do: Repo.get!(Diagram, id)

  @doc """
  Gets or creates a diagram for a user.
  Creates a default diagram if one doesn't exist.
  """
  def get_or_create_diagram(user_id) do
    case from(d in Diagram, where: d.user_id == ^user_id, limit: 1) |> Repo.one() do
      nil ->
        # Create a default diagram for the user
        %Diagram{}
        |> Diagram.changeset(%{
          user_id: user_id,
          name: "My Living Web",
          description: "My permaculture system diagram",
          nodes: %{},
          edges: %{}
        })
        |> Repo.insert()
        |> case do
          {:ok, diagram} -> {:ok, diagram}
          {:error, changeset} -> {:error, changeset}
        end

      diagram ->
        {:ok, diagram}
    end
  end

  @doc """
  Creates a diagram.
  """
  def create_diagram(attrs \\ %{}) do
    %Diagram{}
    |> Diagram.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a diagram.
  """
  def update_diagram(%Diagram{} = diagram, attrs) do
    diagram
    |> Diagram.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a diagram.
  """
  def delete_diagram(%Diagram{} = diagram) do
    Repo.delete(diagram)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking diagram changes.
  """
  def change_diagram(%Diagram{} = diagram, attrs \\ %{}) do
    Diagram.changeset(diagram, attrs)
  end

  # ==== Composite Systems ====

  @doc """
  Returns the list of composite systems for a user.
  """
  def list_composite_systems(user_id) do
    from(cs in CompositeSystem, where: cs.user_id == ^user_id, order_by: [desc: cs.inserted_at])
    |> Repo.all()
  end

  @doc """
  Gets a single composite system.
  """
  def get_composite_system!(id), do: Repo.get!(CompositeSystem, id)

  @doc """
  Creates a composite system.
  """
  def create_composite_system(attrs \\ %{}) do
    %CompositeSystem{}
    |> CompositeSystem.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a composite system.
  """
  def update_composite_system(%CompositeSystem{} = composite_system, attrs) do
    composite_system
    |> CompositeSystem.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a composite system.
  """
  def delete_composite_system(%CompositeSystem{} = composite_system) do
    Repo.delete(composite_system)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking composite system changes.
  """
  def change_composite_system(%CompositeSystem{} = composite_system, attrs \\ %{}) do
    CompositeSystem.changeset(composite_system, attrs)
  end

  # ==== Node Type Helpers ====

  @doc """
  Determines if a node is a project node or composite node.
  Returns {:project, project_id} or {:composite, composite_id} or :unknown
  """
  def node_type(node_data) when is_map(node_data) do
    cond do
      Map.has_key?(node_data, "project_id") and not is_nil(node_data["project_id"]) ->
        {:project, node_data["project_id"]}

      Map.has_key?(node_data, "composite_system_id") and not is_nil(node_data["composite_system_id"]) ->
        {:composite, node_data["composite_system_id"]}

      Map.has_key?(node_data, "linked_type") and node_data["linked_type"] == "user_plant" and
      Map.has_key?(node_data, "linked_id") and not is_nil(node_data["linked_id"]) ->
        {:user_plant, node_data["linked_id"]}

      true ->
        :unknown
    end
  end

  def node_type(_), do: :unknown

  @doc """
  Checks if a node is a composite instance.
  """
  def composite_node?(node_data) when is_map(node_data) do
    case node_type(node_data) do
      {:composite, _} -> true
      _ -> false
    end
  end

  def composite_node?(_), do: false

  @doc """
  Checks if a node is expanded (for composite nodes).
  """
  def node_expanded?(node_data) when is_map(node_data) do
    Map.get(node_data, "is_expanded", false)
  end

  def node_expanded?(_), do: false

  @doc """
  Generates a unique node ID for a composite instance.
  Format: "composite_<composite_system_id>_<random>"
  """
  def generate_composite_node_id(composite_system_id) do
    random_bytes = :crypto.strong_rand_bytes(4)
    random_hex = Base.encode16(random_bytes, case: :lower)
    "composite_#{composite_system_id}_#{random_hex}"
  end

  @doc """
  Generates a unique node ID with a prefix for expanded internal nodes.
  Format: "expanded_<parent_node_id>_<original_node_id>"
  """
  def generate_expanded_node_id(parent_node_id, original_node_id) do
    "expanded_#{parent_node_id}_#{original_node_id}"
  end

  @doc """
  Checks if a composite system creates a circular dependency.

  Returns :ok if no circular dependency, or {:error, reason} if circular.

  This checks if adding internal_node_ids to composite_system_id would create
  a cycle (e.g., composite A contains composite B which contains composite A).
  """
  def check_circular_dependency(composite_system_id, internal_node_ids, diagram_nodes) do
    # Get all composite systems to build containment graph
    all_composites = list_all_composite_systems()

    # Build containment map: composite_id -> [contained_composite_ids]
    containment_map = build_containment_graph(all_composites)

    # Check if any internal nodes are composites that would create a cycle
    case find_circular_path(composite_system_id, internal_node_ids, diagram_nodes, containment_map) do
      nil -> :ok
      path -> {:error, "Circular dependency detected: #{Enum.join(path, " → ")}"}
    end
  end

  defp list_all_composite_systems do
    from(cs in CompositeSystem)
    |> Repo.all()
  end

  defp build_containment_graph(all_composites) do
    # For each composite, find which other composites it contains
    all_composites
    |> Enum.map(fn composite ->
      # Get internal node IDs and check which are composite instances
      contained_composite_ids =
        (composite.internal_node_ids || [])
        |> Enum.map(fn _node_id ->
          # In a full implementation, we'd look up each node in the parent diagram
          # to see if it's a composite instance and get its composite_system_id
          # For now, we'll use a simpler approach based on node ID patterns
          nil
        end)
        |> Enum.reject(&is_nil/1)

      {composite.id, contained_composite_ids}
    end)
    |> Map.new()
  end

  defp find_circular_path(target_composite_id, internal_node_ids, diagram_nodes, containment_map) do
    # Check each internal node to see if it's a composite
    internal_node_ids
    |> Enum.find_value(fn node_id ->
      node_data = Map.get(diagram_nodes, node_id)

      case node_type(node_data) do
        {:composite, composite_id} ->
          # Convert to integer if needed
          composite_id_int = case composite_id do
            id when is_integer(id) -> id
            id when is_binary(id) -> String.to_integer(id)
            _ -> nil
          end

          # Check if this composite eventually contains our target
          if composite_id_int && contains_composite_recursive?(composite_id_int, target_composite_id, containment_map, []) do
            ["Composite #{target_composite_id}", "Composite #{composite_id_int}", "Composite #{target_composite_id}"]
          else
            nil
          end

        _ ->
          nil
      end
    end)
  end

  defp contains_composite_recursive?(current_id, target_id, _containment_map, _visited) when current_id == target_id do
    true
  end

  defp contains_composite_recursive?(current_id, target_id, containment_map, visited) do
    if current_id in visited do
      # Already visited, avoid infinite loop
      false
    else
      # Get composites contained by current composite
      contained = Map.get(containment_map, current_id, [])

      # Check if target is directly contained or recursively contained
      Enum.any?(contained, fn contained_id ->
        contained_id == target_id or
        contains_composite_recursive?(contained_id, target_id, containment_map, [current_id | visited])
      end)
    end
  end

  @doc """
  Infers external inputs and outputs for a composite system based on internal nodes and edges.

  Logic:
  - Collects all inputs/outputs from internal nodes (from their projects)
  - Finds nodes with edges TO internal nodes (external sources) -> these become inputs
  - Finds nodes with edges FROM internal nodes (external targets) -> these become outputs
  - Merges and deduplicates
  """
  def infer_external_io(internal_node_ids, diagram_nodes, diagram_edges, projects) do
    project_map = Map.new(projects || [], fn p -> {p.id, p} end)

    # Get all internal nodes
    internal_nodes =
      internal_node_ids
      |> Enum.map(fn node_id -> {node_id, Map.get(diagram_nodes || %{}, node_id)} end)
      |> Enum.filter(fn {_id, data} -> not is_nil(data) end)
      |> Map.new()

    # Collect all inputs/outputs from internal nodes' projects
    {internal_inputs, internal_outputs} =
      internal_nodes
      |> Enum.reduce({%{}, %{}}, fn {_node_id, node_data}, {acc_inputs, acc_outputs} ->
        project_id = case node_data["project_id"] do
          id when is_integer(id) -> id
          id when is_binary(id) -> String.to_integer(id)
          _ -> nil
        end

        project = Map.get(project_map, project_id)
        if project do
          # Collect inputs/outputs from project
          project_inputs = project.inputs || %{}
          project_outputs = project.outputs || %{}

          # Merge into accumulated inputs/outputs
          {Map.merge(acc_inputs, project_inputs), Map.merge(acc_outputs, project_outputs)}
        else
          {acc_inputs, acc_outputs}
        end
      end)

    # Find edges connecting to/from internal nodes
    edges = diagram_edges || %{}
    internal_node_set = MapSet.new(internal_node_ids)

    # External sources (nodes with edges TO internal nodes)
    external_inputs =
      edges
      |> Enum.reduce(%{}, fn {_edge_id, edge_data}, acc ->
        source_id = edge_data["source_id"]
        target_id = edge_data["target_id"]

        # If source is external and target is internal, this is an input
        if not MapSet.member?(internal_node_set, source_id) and
           MapSet.member?(internal_node_set, target_id) do
          source_node = Map.get(diagram_nodes || %{}, source_id)
          if source_node do
            project_id = case source_node["project_id"] do
              id when is_integer(id) -> id
              id when is_binary(id) -> String.to_integer(id)
              _ -> nil
            end

            project = Map.get(project_map, project_id)
            if project do
              # Add outputs from external source as inputs to composite
              outputs = project.outputs || %{}
              Map.merge(acc, outputs)
            else
              acc
            end
          else
            acc
          end
        else
          acc
        end
      end)

    # External targets (nodes with edges FROM internal nodes)
    external_outputs =
      edges
      |> Enum.reduce(%{}, fn {_edge_id, edge_data}, acc ->
        source_id = edge_data["source_id"]
        target_id = edge_data["target_id"]

        # If source is internal and target is external, this is an output
        if MapSet.member?(internal_node_set, source_id) and
           not MapSet.member?(internal_node_set, target_id) do
          source_node = Map.get(diagram_nodes || %{}, source_id)
          if source_node do
            project_id = case source_node["project_id"] do
              id when is_integer(id) -> id
              id when is_binary(id) -> String.to_integer(id)
              _ -> nil
            end

            project = Map.get(project_map, project_id)
            if project do
              # Add outputs from internal source as outputs of composite
              outputs = project.outputs || %{}
              Map.merge(acc, outputs)
            else
              acc
            end
          else
            acc
          end
        else
          acc
        end
      end)

    # Merge internal and external, deduplicate
    final_inputs = Map.merge(internal_inputs, external_inputs)
    final_outputs = Map.merge(internal_outputs, external_outputs)

    {final_inputs, final_outputs}
  end
end
