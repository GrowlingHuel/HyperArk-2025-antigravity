defmodule GreenManTavernWeb.LivingWebHelpers do
  @moduledoc """
  Helper functions for the Living Web panel.
  """

  require Logger
  alias GreenManTavern.{Diagrams, Systems}

  def parse_integer(string) when is_binary(string) do
    case Integer.parse(string) do
      {int, ""} -> {:ok, int}
      _ -> {:error, :invalid_integer}
    end
  end
  def parse_integer(int) when is_integer(int), do: {:ok, int}
  def parse_integer(_), do: {:error, :invalid_type}

  def parse_int(nil), do: nil
  def parse_int(<<>>), do: nil
  def parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> i
      _ -> nil
    end
  end
  def parse_int(val) when is_integer(val), do: val
  def parse_int(_), do: nil

  # Helper to filter out hidden nodes before sending to client
  def filter_visible_nodes(nodes) when is_map(nodes) do
    nodes
    |> Enum.reject(fn {_id, node} -> Map.get(node, "hidden") == true end)
    |> Enum.into(%{})
  end
  def filter_visible_nodes(_), do: %{}

  # Helper: convert Ecto structs to plain maps for JSON encoding in template
  def projects_for_json(projects) when is_list(projects) do
    Enum.map(projects, fn p ->
      %{
        id: p.id,
        name: p.name,
        icon_name: p.icon_name,
        category: p.category,
        skill_level: Map.get(p, :skill_level),
        inputs: p.inputs || %{},
        outputs: p.outputs || %{}
      }
    end)
  end
  def projects_for_json(_), do: []

  def enrich_nodes_with_project_data(raw_nodes, projects, composite_systems \\ []) do
    project_map = Map.new(projects, fn p -> {p.id, p} end)
    composite_map = Map.new(composite_systems, fn c -> {c.id, c} end)

    Enum.reduce(raw_nodes, %{}, fn {node_id, node_data}, acc ->
      case Diagrams.node_type(node_data) do
        {:project, project_id} ->
          # Convert project_id to integer if it's a string
          project_id_int = case project_id do
            id when is_integer(id) -> id
            id when is_binary(id) -> String.to_integer(id)
            _ -> nil
          end

          case Map.get(project_map, project_id_int) do
            nil ->
              enriched = Map.merge(node_data, %{
                "name" => "Unknown Project",
                "category" => "unknown",
                "icon_name" => "unknown"
              })
              Map.put(acc, node_id, enriched)

            project ->
              enriched = Map.merge(node_data, %{
                "name" => project.name,
                "category" => project.category,
                "icon_name" => project.icon_name,
                "inputs" => extract_project_inputs(project),
                "outputs" => extract_project_outputs(project)
              })
              Map.put(acc, node_id, enriched)
          end

        {:composite, composite_id} ->
          # Convert composite_id to integer if it's a string
          composite_id_int = case composite_id do
            id when is_integer(id) -> id
            id when is_binary(id) -> String.to_integer(id)
            _ -> nil
          end

          case Map.get(composite_map, composite_id_int) do
            nil ->
              enriched = Map.merge(node_data, %{
                "name" => "Unknown Composite",
                "category" => "composite",
                "icon_name" => "📦"
              })
              Map.put(acc, node_id, enriched)

            composite ->
              enriched = Map.merge(node_data, %{
                "name" => composite.name,
                "category" => "composite",
                "icon_name" => composite.icon_name || "📦",
                "description" => composite.description,
                "composite_system_id" => composite_id_int,
                "is_composite" => true
              })

              # Add aggregated I/O from child nodes if composite is collapsed
              is_expanded = Map.get(node_data, "is_expanded", false)
              final_enriched = if not is_expanded do
                internal_nodes = composite.internal_nodes_data || %{}
                nodes_to_check = if map_size(internal_nodes) > 0 do
                  internal_nodes
                else
                  raw_nodes
                end
                aggregated = aggregate_composite_io(composite_id_int, nodes_to_check)
                enriched
                  |> Map.put("inputs", aggregated["inputs"])
                  |> Map.put("outputs", aggregated["outputs"])
              else
                enriched
              end

              Map.put(acc, node_id, final_enriched)
          end

        {:user_plant, plant_id} ->
          enriched = Map.merge(node_data, %{
            "name" => Map.get(node_data, "name", "Plant"),
            "category" => "food",
            "icon_name" => "🌿",
            "is_user_plant" => true,
            "linked_type" => "user_plant",
            "linked_id" => plant_id
          })
          Map.put(acc, node_id, enriched)

        :unknown ->
          Map.put(acc, node_id, node_data)
      end
    end)
  end

  defp extract_project_inputs(project) do
    case Map.get(project, :inputs) do
      inputs when is_map(inputs) -> Map.keys(inputs) || []
      _ ->
        case Map.get(project, :inputs) do
          inputs when is_map(inputs) -> Map.keys(inputs) || []
          _ -> []
        end
    end
  end

  defp extract_project_outputs(project) do
    case Map.get(project, :outputs) do
      outputs when is_map(outputs) -> Map.keys(outputs) || []
      _ ->
        case Map.get(project, :outputs) do
          outputs when is_map(outputs) -> Map.keys(outputs) || []
          _ -> []
        end
    end
  end

  defp aggregate_composite_io(composite_id, nodes) do
    # Find all child nodes
    child_nodes = Enum.filter(nodes, fn {_id, node} ->
      Map.get(node, "parent_composite_id") == composite_id
    end)

    # Collect all inputs and outputs
    inputs = Enum.flat_map(child_nodes, fn {_id, node} ->
      Map.get(node, "inputs", [])
    end) |> Enum.uniq()

    outputs = Enum.flat_map(child_nodes, fn {_id, node} ->
      Map.get(node, "outputs", [])
    end) |> Enum.uniq()

    %{"inputs" => inputs, "outputs" => outputs}
  end

  def detect_potential_connections(nodes, edges) do
    # Get all actual connections as set for quick lookup
    actual_connections =
      edges
      |> Enum.map(fn {_id, edge} ->
        {edge["source_id"], edge["source_handle"], edge["target_id"], edge["target_handle"]}
      end)
      |> MapSet.new()

    # Find all potential connections
    nodes
    |> Enum.reduce([], fn {source_id, source_node}, acc ->
      source_outputs = Map.get(source_node, "outputs", [])

      source_potential =
        source_outputs
        |> Enum.reduce([], fn output, output_acc ->
          # Check if this output is already connected
          output_connected =
            actual_connections
            |> Enum.any?(fn {sid, sh, _tid, _th} ->
              sid == source_id && sh == output
            end)

          if output_connected do
            output_acc
          else
            # Find nodes with matching unconnected input
            target_potential =
              nodes
              |> Enum.reduce([], fn {target_id, target_node}, target_acc ->
                if target_id != source_id do
                  target_inputs = Map.get(target_node, "inputs", [])

                  if output in target_inputs do
                    # Check if this input is already connected
                    input_connected =
                      actual_connections
                      |> Enum.any?(fn {_sid, _sh, tid, th} ->
                        tid == target_id && th == output
                      end)

                    if input_connected do
                      target_acc
                    else
                      [%{
                        "source_id" => source_id,
                        "target_id" => target_id,
                        "resource_type" => output,
                        "connection_type" => "potential"
                      } | target_acc]
                    end
                  else
                    target_acc
                  end
                else
                  target_acc
                end
              end)

            target_potential ++ output_acc
          end
        end)

      source_potential ++ acc
    end)
  end

  def calculate_node_io_data(node_id, node_data, all_nodes, all_edges) do
    # Get available inputs/outputs from node data
    available_inputs = Map.get(node_data, "inputs", [])
    available_outputs = Map.get(node_data, "outputs", [])

    # Find actual connections
    actual_inputs =
      all_edges
      |> Enum.filter(fn {_id, edge} -> edge["target_id"] == node_id end)
      |> Enum.map(fn {_id, edge} ->
        source_node = Map.get(all_nodes, edge["source_id"])
        %{
          resource: edge["resource_type"],
          from_node_id: edge["source_id"],
          from_node_name: if(source_node, do: Map.get(source_node, "name"), else: "Unknown")
        }
      end)

    actual_outputs =
      all_edges
      |> Enum.filter(fn {_id, edge} -> edge["source_id"] == node_id end)
      |> Enum.map(fn {_id, edge} ->
        target_node = Map.get(all_nodes, edge["target_id"])
        %{
          resource: edge["resource_type"],
          to_node_id: edge["target_id"],
          to_node_name: if(target_node, do: Map.get(target_node, "name"), else: "Unknown")
        }
      end)

    # Calculate potential connections (unused inputs/outputs)
    potential_inputs =
      available_inputs
      |> Enum.reject(fn input ->
        Enum.any?(actual_inputs, fn actual -> actual.resource == input end)
      end)

    potential_outputs =
      available_outputs
      |> Enum.reject(fn output ->
        Enum.any?(actual_outputs, fn actual -> actual.resource == output end)
      end)

    %{
      "actual_inputs" => actual_inputs,
      "actual_outputs" => actual_outputs,
      "potential_inputs" => potential_inputs,
      "potential_outputs" => potential_outputs
    }
  end

  def maybe_add_port_info(edge_map, _key, nil), do: edge_map
  def maybe_add_port_info(edge_map, key, value) when is_binary(value) do
    Map.put(edge_map, key, value)
  end
  def maybe_add_port_info(edge_map, _key, _value), do: edge_map

  def get_composite_safe(composite_id) do
    try do
      Diagrams.get_composite_system!(composite_id)
    rescue
      _ -> nil
    end
  end

  def detect_boundary_edges(composite_id, nodes, edges) do
    Logger.info("[PortDetection] Analyzing boundary edges for composite: #{composite_id}")

    input_edges =
      Enum.filter(edges, fn {_edge_id, edge} ->
        target_id = Map.get(edge, "target_id") || Map.get(edge, "target")
        source_id = Map.get(edge, "source_id") || Map.get(edge, "source")

        target_node = Map.get(nodes, target_id)
        source_node = Map.get(nodes, source_id)

        target_parent = Map.get(target_node || %{}, "parent_composite_id")
        source_parent = Map.get(source_node || %{}, "parent_composite_id")

        target_parent == composite_id && source_parent != composite_id
      end)

    output_edges =
      Enum.filter(edges, fn {_edge_id, edge} ->
        target_id = Map.get(edge, "target_id") || Map.get(edge, "target")
        source_id = Map.get(edge, "source_id") || Map.get(edge, "source")

        target_node = Map.get(nodes, target_id)
        source_node = Map.get(nodes, source_id)

        target_parent = Map.get(target_node || %{}, "parent_composite_id")
        source_parent = Map.get(source_node || %{}, "parent_composite_id")

        source_parent == composite_id && target_parent != composite_id
      end)

    %{
      input_edges: input_edges,
      output_edges: output_edges
    }
  end

  def resolve_connection_endpoints(edges, nodes, expanded_composites) do
    expanded_set = MapSet.new(expanded_composites)

    Enum.map(edges, fn {edge_id, edge} ->
      resolved_edge = edge
        |> resolve_connection_target(nodes, expanded_set)
        |> resolve_connection_source(nodes, expanded_set)

      {edge_id, resolved_edge}
    end)
    |> Enum.into(%{})
  end

  defp resolve_connection_target(edge, nodes, expanded_composites) do
    target_id = edge["target_id"]
    target_node = Map.get(nodes, target_id)

    if target_node && Map.get(target_node, "is_composite") && MapSet.member?(expanded_composites, target_id) do
      target_handle = edge["target_handle"]

      child_with_input = Enum.find(nodes, fn {_id, node} ->
        Map.get(node, "parent_composite_id") == target_id &&
        target_handle in (Map.get(node, "inputs", []))
      end)

      case child_with_input do
        {child_id, _} ->
          Map.put(edge, "target_id", child_id)
        nil ->
          edge
      end
    else
      edge
    end
  end

  defp resolve_connection_source(edge, nodes, expanded_composites) do
    source_id = edge["source_id"]
    source_node = Map.get(nodes, source_id)

    if source_node && Map.get(source_node, "is_composite") && MapSet.member?(expanded_composites, source_id) do
      source_handle = edge["source_handle"]

      child_with_output = Enum.find(nodes, fn {_id, node} ->
        Map.get(node, "parent_composite_id") == source_id &&
        source_handle in (Map.get(node, "outputs", []))
      end)

      case child_with_output do
        {child_id, _} ->
          Map.put(edge, "source_id", child_id)
        nil ->
          edge
      end
    else
      edge
    end
  end

  def reroute_edges_for_expanded_composite(edges, composite_id, nodes) do
    Enum.map(edges, fn {edge_id, edge} ->
      rerouted = edge
        |> reroute_if_target_is_composite(composite_id, nodes)
        |> reroute_if_source_is_composite(composite_id, nodes)

      {edge_id, rerouted}
    end)
    |> Enum.into(%{})
  end

  defp reroute_if_target_is_composite(edge, composite_id, nodes) do
    if edge["target_id"] == composite_id do
      target_handle = edge["target_handle"]

      child_with_input = Enum.find(nodes, fn {_node_id, node} ->
        Map.get(node, "parent_composite_id") == composite_id &&
        target_handle in (Map.get(node, "inputs", []))
      end)

      case child_with_input do
        {child_id, _child_node} ->
          Map.put(edge, "target_id", child_id)
        nil ->
          edge
      end
    else
      edge
    end
  end

  defp reroute_if_source_is_composite(edge, composite_id, nodes) do
    if edge["source_id"] == composite_id do
      source_handle = edge["source_handle"]

      child_with_output = Enum.find(nodes, fn {_node_id, node} ->
        Map.get(node, "parent_composite_id") == composite_id &&
        source_handle in (Map.get(node, "outputs", []))
      end)

      case child_with_output do
        {child_id, _child_node} ->
          Map.put(edge, "source_id", child_id)
        nil ->
          edge
      end
    else
      edge
    end
  end

  def reroute_edges_for_collapsed_composite(edges, composite_id, nodes) do
    child_node_ids = Enum.filter(nodes, fn {_id, node} ->
      Map.get(node, "parent_composite_id") == composite_id
    end)
    |> Enum.map(fn {id, _} -> id end)
    |> MapSet.new()

    Enum.map(edges, fn {edge_id, edge} ->
      rerouted = edge

      rerouted = if MapSet.member?(child_node_ids, edge["target_id"]) do
        Map.put(rerouted, "target_id", composite_id)
      else
        rerouted
      end

      rerouted = if MapSet.member?(child_node_ids, edge["source_id"]) do
        Map.put(rerouted, "source_id", composite_id)
      else
        rerouted
      end

      {edge_id, rerouted}
    end)
    |> Enum.into(%{})
  end

  def analyze_system_opportunities(nodes, edges) do
    opportunities = []

    connected_node_ids = MapSet.new(
      Enum.flat_map(edges, fn {_id, edge} ->
        [edge["source_id"], edge["target_id"]]
      end)
    )

    isolated_nodes = Enum.filter(nodes, fn {node_id, _node} ->
      !MapSet.member?(connected_node_ids, node_id)
    end)

    opportunities =
      isolated_nodes
      |> Enum.reduce(opportunities, fn {node_id, node}, acc ->
        inputs = node["inputs"] || []
        outputs = node["outputs"] || []

        if length(inputs) > 0 || length(outputs) > 0 do
          [%{
            "type" => "isolated_node",
            "priority" => "high",
            "node_id" => node_id,
            "title" => "Connect #{Map.get(node, "name", "Node")}",
            "description" => "This node has no connections yet. It has #{length(outputs)} output(s) and #{length(inputs)} input(s) available.",
            "action" => "connect_node",
            "action_data" => %{"node_id" => node_id}
          } | acc]
        else
          acc
        end
      end)

    nodes
    |> Enum.reduce(opportunities, fn {node_id, node}, acc ->
      outputs = Map.get(node, "outputs", [])

      output_opportunities =
        outputs
        |> Enum.reduce([], fn output, output_acc ->
          is_connected = Enum.any?(edges, fn {_id, edge} ->
            edge["source_id"] == node_id && edge["source_handle"] == output
          end)

          if is_connected do
            output_acc
          else
            potential_targets = Enum.filter(nodes, fn {target_id, target_node} ->
              target_id != node_id && output in Map.get(target_node, "inputs", [])
            end)

            if length(potential_targets) > 0 do
              [%{
                "type" => "unused_output",
                "priority" => "medium",
                "node_id" => node_id,
                "resource" => output,
                "title" => "Use #{output} from #{Map.get(node, "name", "Node")}",
                "description" => "This node produces #{output} but it's not being used. #{length(potential_targets)} node(s) could use it.",
                "action" => "show_targets",
                "action_data" => %{
                  "source_id" => node_id,
                  "resource" => output,
                  "targets" => Enum.map(potential_targets, fn {tid, _} -> tid end)
                }
              } | output_acc]
            else
              output_acc
            end
          end
        end)

      output_opportunities ++ acc
    end)
  end
end
