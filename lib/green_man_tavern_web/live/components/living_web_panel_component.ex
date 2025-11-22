defmodule GreenManTavernWeb.LivingWebPanelComponent do
  use GreenManTavernWeb, :live_component

  require Logger
  alias GreenManTavern.{Systems, Diagrams, PlantingGuide, Inventory, Repo}
  alias GreenManTavern.Diagrams.Suggestions
  alias GreenManTavernWeb.LivingWebHelpers
  alias GreenManTavernWeb.TextFormattingHelpers

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Initialize data if not present (first load)
    socket = if is_nil(socket.assigns[:nodes]) do
      current_user = socket.assigns[:current_user]
      user_id = if current_user, do: current_user.id, else: nil

      # Load Living Web data
      projects = Systems.list_projects()

      diagram =
        if current_user do
          case Diagrams.get_or_create_diagram(current_user.id) do
            {:ok, d} -> d
            _ -> nil
          end
        else
          nil
        end

      raw_nodes = if diagram && is_map(diagram.nodes), do: diagram.nodes, else: %{}
      edges = if diagram && is_map(diagram.edges), do: diagram.edges, else: %{}

      # Load composite systems for the user
      composite_systems = if user_id, do: Diagrams.list_composite_systems(user_id), else: []

      # Enrich nodes with both project and composite data
      nodes = LivingWebHelpers.enrich_nodes_with_project_data(raw_nodes, projects, composite_systems)

      # Calculate potential connections
      potential_edges = LivingWebHelpers.detect_potential_connections(nodes, edges)

      socket
      |> assign(:projects, projects)
      |> assign(:diagram, diagram)
      |> assign(:nodes, nodes)
      |> assign(:edges, edges)
      |> assign(:potential_edges, potential_edges)
      |> assign(:composite_systems, composite_systems)
      |> assign(:selected_nodes, [])
      |> assign(:expanded_composites, [])
      |> assign(:show_detail_panel, false)
      |> assign(:selected_node_info, nil)
      |> assign(:show_system_dialog, false)
      |> assign(:show_harvest_panel, false)
      |> assign(:selected_living_web_node, nil)
      |> assign(:history_stack, [])
      |> assign(:history_index, -1)
    else
      socket
    end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="living-web-content" style="flex: 1; display: flex; overflow: hidden; height: 100%; min-height: 0;">
      <style>
        .living-web-content { flex: 1; display: flex; overflow: hidden; height: 100%; min-height: 0; }
        .living-web-library { width: 200px; background: #E8E8E8; border-right: 2px solid #000; overflow: hidden; display: flex; flex-direction: column; font-family: Georgia, 'Times New Roman', serif; height: 100%; min-height: 0; }
        .living-web-canvas { flex: 1; background: #F8F8F8; border: 2px solid #000; min-height: 0; overflow: hidden; display: flex; flex-direction: column; height: 100%; position: relative; }
        .canvas-scroll-area {
          flex: 1;
          overflow: auto;
          min-height: 0;
          position: relative;
          background: #FFF;
          background-image:
            radial-gradient(circle, #D4D4D4 0.75px, transparent 0.75px),
            radial-gradient(circle, #D4D4D4 0.75px, transparent 0.75px),
            radial-gradient(circle, #CCCCCC 1px, transparent 1px);
          background-size: 20px 20px;
          background-position: 10px 10px, 0px 0px, 0px 0px;
          background-repeat: repeat;
          background-attachment: local;
        }
        #xyflow-container {
          width: 100%;
          height: 100%;
          position: relative;
          background: transparent;
          min-width: 100%;
          min-height: 100%;
        }
        .flow-canvas { position: relative; top: 0; left: 0; width: 100%; height: 100%; }
        .library-header { font-size: 11px; font-weight: bold; color: #000; text-transform: uppercase; letter-spacing: 1px; padding: 8px 10px; border-bottom: 1px solid #000; height: 40px; display: flex; align-items: center; flex-shrink: 0; position: sticky; top: 0; background: #E8E8E8; z-index: 10; }
        .library-content { flex: 1; overflow-y: auto; padding: 10px; min-height: 0; }
        .library-section { margin-bottom: 16px; }
        .library-section-title { font-size: 9px; font-weight: bold; color: #000; text-transform: uppercase; letter-spacing: 0.5px; padding: 4px 6px; background: #EEE; border: 1px solid #000; margin-bottom: 6px; }
        .library-item { display: flex; align-items: center; padding: 6px 8px; margin-bottom: 4px; background: #FFF; border: 1px solid #CCC; font-size: 11px; }
        .draggable-project-item { cursor: grab; user-select: none; }
        .draggable-project-item:hover { background: #EEE; border-color: #000; }
        .library-icon { margin-right: 6px; font-size: 14px; filter: grayscale(100%) contrast(1000%) !important; }
        .library-name { color: #000; font-family: Georgia, 'Times New Roman', serif; }
        /* Greyscale checkbox styling - only change color, keep everything else the same */
        .node-select-checkbox {
          accent-color: #000 !important;
          filter: grayscale(100%) !important;
        }
        .node-select-checkbox:checked {
          filter: grayscale(100%) !important;
        }
      </style>

      <!-- Left Panel: Systems Library -->
      <div class="living-web-library">
        <div class="library-header">SYSTEMS LIBRARY</div>

        <div class="library-content">
          <!-- Composite Systems Section -->
          <%= if length(@composite_systems) > 0 do %>
            <div class="library-section">
              <div class="library-section-title">YOUR SYSTEMS</div>
              <%= for system <- @composite_systems do %>
                <div
                  class="library-item draggable-project-item"
                  draggable="true"
                  phx-hook="DraggableProject"
                  id={"composite-#{system.id}"}
                  data-project-id={"composite-#{system.id}"}
                  data-composite-id={system.id}
                  data-name={system.name}
                  data-icon={system.icon_name || "📦"}
                >
                  <span class="library-icon"><%= system.icon_name || "📦" %></span>
                  <span class="library-name"><%= system.name %></span>
                </div>
              <% end %>
            </div>
          <% end %>

          <!-- Standard Projects Section -->
          <%= for category <- Enum.uniq(Enum.map(@projects, & &1.category)) |> Enum.sort() do %>
            <div class="library-section">
              <div class="library-section-title"><%= String.upcase(category) %></div>
              <%= for project <- Enum.filter(@projects, & &1.category == category) do %>
                <div
                  class="library-item draggable-project-item"
                  draggable="true"
                  phx-hook="DraggableProject"
                  id={"project-#{project.id}"}
                  data-project-id={project.id}
                  data-name={project.name}
                  data-icon={project.icon_name}
                >
                  <span class="library-icon"><%= project.icon_name %></span>
                  <span class="library-name"><%= project.name %></span>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Main Canvas Area -->
      <div class="living-web-canvas">
        <!-- Toolbar -->
        <div class="canvas-toolbar" style="
          height: 40px;
          background: #E8E8E8;
          border-bottom: 2px solid #000;
          display: flex;
          align-items: center;
          padding: 0 10px;
          gap: 8px;
          flex-shrink: 0;
          z-index: 10;
        ">
          <button
            type="button"
            id="show-all-btn"
            phx-click="show_all_nodes"
            phx-target={@myself}
            class="toolbar-btn"
            style="
              padding: 4px 12px;
              background: #FFF;
              border: 2px solid #000;
              border-radius: 0;
              font-size: 11px;
              font-family: Georgia, 'Times New Roman', serif;
              cursor: pointer;
              box-shadow: 1px 1px 0 rgba(0,0,0,0.3);
            "
          >
            Show All
          </button>

          <button
            type="button"
            id="connect-btn"
            class="toolbar-btn"
            style="
              padding: 4px 12px;
              background: #FFF;
              border: 2px solid #000;
              border-radius: 0;
              font-size: 11px;
              font-family: Georgia, 'Times New Roman', serif;
              cursor: pointer;
              box-shadow: 1px 1px 0 rgba(0,0,0,0.3);
              opacity: 0.5;
            "
            disabled
          >
            Connect
          </button>

          <button
            type="button"
            id="save-as-system-btn"
            phx-click="show_save_system_dialog"
            phx-target={@myself}
            class="toolbar-btn"
            style={[
              "padding: 4px 12px;",
              "background: #FFF;",
              "border: 2px solid #000;",
              "border-radius: 0;",
              "font-size: 11px;",
              "font-family: Georgia, 'Times New Roman', serif;",
              "cursor: pointer;",
              "box-shadow: 1px 1px 0 rgba(0,0,0,0.3);",
              if(length(assigns[:selected_nodes] || []) >= 2, do: "opacity: 1;", else: "opacity: 0.5;")
            ]}
            disabled={length(assigns[:selected_nodes] || []) < 2}
          >
            Save as System
          </button>

          <button
            type="button"
            id="suggestions-btn"
            class="toolbar-btn"
            style="
              padding: 4px 12px;
              background: #FFF;
              border: 2px solid #000;
              border-radius: 0;
              font-size: 11px;
              font-family: Georgia, 'Times New Roman', serif;
              cursor: pointer;
              box-shadow: 1px 1px 0 rgba(0,0,0,0.3);
            "
            phx-click="show_suggestions"
            phx-target={@myself}
          >
            Suggestions
          </button>

          <button
            type="button"
            id="reset-zoom-btn"
            class="toolbar-btn"
            style="
              padding: 4px 12px;
              background: #FFF;
              border: 2px solid #000;
              border-radius: 0;
              font-size: 11px;
              font-family: Georgia, 'Times New Roman', serif;
              cursor: pointer;
              box-shadow: 1px 1px 0 rgba(0,0,0,0.3);
            "
            phx-click="reset_zoom"
            phx-target={@myself}
            title="Reset zoom and pan (0)"
          >
            Reset View (0)
          </button>

          <button
            type="button"
            id="deselect-all-btn"
            class="toolbar-btn"
            style="
              padding: 4px 12px;
              background: #FFF;
              border: 2px solid #000;
              border-radius: 0;
              font-size: 11px;
              font-family: Georgia, 'Times New Roman', serif;
              cursor: pointer;
              box-shadow: 1px 1px 0 rgba(0,0,0,0.3);
            "
          >
            Deselect All
          </button>

          <button
            type="button"
            id="clear-all-btn"
            class="toolbar-btn"
            style="
              padding: 4px 12px;
              background: #FFF;
              border: 2px solid #000;
              border-radius: 0;
              font-size: 11px;
              font-family: Georgia, 'Times New Roman', serif;
              cursor: pointer;
              box-shadow: 1px 1px 0 rgba(0,0,0,0.3);
              margin-left: auto;
            "
            phx-click="clear_canvas"
            phx-target={@myself}
          >
            Clear All
          </button>

          <span id="selection-count" style="
            font-size: 10px;
            color: #666;
            margin-left: 10px;
            font-family: Georgia, 'Times New Roman', serif;
          ">
            <%= length(assigns[:selected_nodes] || []) %> selected
          </span>
        </div>

        <!-- Breadcrumb bar - only visible when composites are expanded -->
        <%= if length(@expanded_composites || []) > 0 do %>
          <div class="breadcrumb-bar" style="
            width: 100%;
            padding: 8px 16px;
            background: #D8D8D8;
            border-bottom: 2px solid #666;
            display: flex;
            align-items: center;
            gap: 8px;
            font-family: Chicago, Geneva, monospace;
            font-size: 11px;
            position: sticky;
            top: 40px;
            z-index: 9;
          ">
            <span style="font-weight: bold; color: #333;">Expanded:</span>

            <%= for composite_id <- @expanded_composites do %>
              <% node = Map.get(@nodes, composite_id) %>
              <%= if node do %>
                <button
                  type="button"
                  phx-click="collapse_composite_node"
                  phx-value-node_id={composite_id}
                  phx-target={@myself}
                  style="
                    padding: 4px 10px;
                    background: #E8E8E8;
                    border: 2px solid #666;
                    border-radius: 0px;
                    font-family: Chicago, Geneva, monospace;
                    font-size: 11px;
                    font-weight: bold;
                    cursor: pointer;
                    display: flex;
                    align-items: center;
                    gap: 4px;
                    box-shadow: 1px 1px 0px #888;
                  "
                  onmouseover="this.style.background='#FFF'; this.style.boxShadow='inset 1px 1px 2px #999'"
                  onmouseout="this.style.background='#E8E8E8'; this.style.boxShadow='1px 1px 0px #888'"
                >
                  <span>📦</span>
                  <span><%= Map.get(node, "name", "System") %></span>
                  <span style="opacity: 0.6; font-size: 10px;">[×]</span>
                </button>
              <% end %>
            <% end %>
          </div>
        <% end %>

        <%!-- Save System Dialog --%>
        <%= if assigns[:show_system_dialog] do %>
          <div class="fixed inset-0 bg-black" style="background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center; z-index: 9999;">
            <div class="bg-white border-2 border-black p-6" style="box-shadow: 4px 4px 0px rgba(0,0,0,0.4); min-width: 400px; font-family: Georgia, 'Times New Roman', serif;">
              <h2 style="font-size: 18px; font-weight: bold; margin-bottom: 16px; color: #000;">Save as System</h2>

              <form phx-submit="save_as_system" phx-target={@myself}>
                <input
                  type="text"
                  name="system_name"
                  placeholder="System name..."
                  class="border-2 border-black px-3 py-2 mb-4 w-full"
                  style="
                    font-family: Georgia, 'Times New Roman', serif;
                    font-size: 13px;
                    padding: 8px 12px;
                    border: 2px solid #000;
                    background: #FFF;
                    box-shadow: 2px 2px 0 #000;
                  "
                  required
                  autofocus
                />

                <p style="font-size: 11px; color: #666; margin-bottom: 16px;">
                  Saving <%= length(assigns[:selected_nodes] || []) %> selected nodes as a composite system.
                </p>

                <div style="display: flex; gap: 10px; justify-content: flex-end;">
                  <button
                    type="button"
                    phx-click="hide_system_dialog"
                    phx-target={@myself}
                    style="
                      padding: 8px 16px;
                      border: 2px solid #000;
                      background: #FFF;
                      font-family: Georgia, 'Times New Roman', serif;
                      font-size: 12px;
                      cursor: pointer;
                      box-shadow: 2px 2px 0 #000;
                    "
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    style="
                      padding: 8px 16px;
                      background: #999;
                      color: #FFF;
                      border: 2px solid #000;
                      font-family: Georgia, 'Times New Roman', serif;
                      font-size: 12px;
                      font-weight: bold;
                      cursor: pointer;
                      box-shadow: 2px 2px 0 #000;
                    "
                  >
                    Save
                  </button>
                </div>
              </form>
            </div>
          </div>
        <% end %>

        <div class="canvas-scroll-area">
          <div
            id="xyflow-container"
            phx-hook="XyflowEditor"
            data-nodes={Jason.encode!(LivingWebHelpers.filter_visible_nodes(@nodes))}
            data-edges={Jason.encode!(@edges)}
            data-projects={Jason.encode!(LivingWebHelpers.projects_for_json(@projects))}
            data-expanded-composites={Jason.encode!(@expanded_composites || [])}
            class="xyflow-editor"
            style="width: 100%; height: 100%; position: relative; background: transparent;"
          >
            <!-- XyFlow editor will render here -->
          </div>

          <%= if @show_harvest_panel && @selected_living_web_node do %>
            <div style="
              position: absolute;
              bottom: 20px;
              right: 20px;
              width: 300px;
              background: #F0F0F0;
              border: 3px solid #000;
              padding: 16px;
              font-family: 'Courier New', monospace;
              box-shadow: 4px 4px 0px #000;
              z-index: 1000;
            ">
              <div style="display: flex; justify-content: space-between; align-items: start; margin-bottom: 12px;">
                <div style="font-weight: bold; font-size: 14px;">
                  <%= @selected_living_web_node.label %>
                </div>
                <button
                  phx-click="close_harvest_panel"
                  phx-target={@myself}
                  style="
                    background: none;
                    border: none;
                    font-size: 18px;
                    cursor: pointer;
                    padding: 0;
                    line-height: 1;
                  "
                >×</button>
              </div>

              <%= if @selected_living_web_node.linked_data do %>
                <%= case @selected_living_web_node.linked_data.type do %>
                  <% "plant" -> %>
                    <div style="margin-bottom: 12px; font-size: 12px;">
                      <div style="color: #666; margin-bottom: 4px;">
                        <strong>Plant:</strong> <%= @selected_living_web_node.linked_data.plant.common_name %>
                      </div>
                      <div style="color: #666; margin-bottom: 4px;">
                        <strong>Status:</strong> <%= @selected_living_web_node.linked_data.user_plant.status %>
                      </div>
                      <div style="color: #666;">
                        <strong>Planted:</strong> <%= if @selected_living_web_node.linked_data.user_plant.actual_planting_date, do: Date.to_string(@selected_living_web_node.linked_data.user_plant.actual_planting_date), else: "Not yet" %>
                      </div>
                    </div>

                    <button
                      phx-click="show_harvest_form"
                      phx-target={@myself}
                      style="
                        width: 100%;
                        background: #4CAF50;
                        color: white;
                        border: 2px solid #000;
                        padding: 8px 16px;
                        font-family: 'Courier New', monospace;
                        font-size: 14px;
                        cursor: pointer;
                        font-weight: bold;
                      "
                    >
                      🌾 HARVEST
                    </button>
                <% end %>
              <% else %>
                <div style="margin-bottom: 12px; font-size: 12px; color: #999;">
                  This node is not linked to a plant or system yet.
                </div>
                <div style="font-size: 11px; color: #666;">
                  (Activation UI coming soon)
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <!-- Node Detail Sidebar Panel -->
        <div
          id="node-detail-panel"
          class={["node-detail-panel", if(@show_detail_panel, do: "", else: "hidden")]}
          style="
            position: absolute;
            top: 40px;
            right: 8px;
            width: 220px;
            height: auto;
            max-height: 600px;
            background: #FFF;
            border: 2px solid #000;
            box-shadow: -2px 2px 8px rgba(0,0,0,0.3);
            z-index: 1000;
            display: flex;
            flex-direction: column;
            font-family: 'Chicago', 'Geneva', monospace;
          "
        >
          <div class="panel-header" style="
            height: 30px;
            min-height: 30px;
            background: #BBBBBB;
            border-bottom: 2px solid #000;
            padding: 0 12px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-shrink: 0;
          ">
            <h3 style="
              margin: 0;
              padding: 0;
              font-size: 12px;
              font-weight: bold;
              color: #000;
              font-family: 'Chicago', 'Geneva', monospace;
            ">Node Details</h3>
            <button
              type="button"
              phx-click="close_detail_panel"
              phx-target={@myself}
              style="
                background: transparent;
                border: 1px solid #666;
                width: 20px;
                height: 20px;
                padding: 0;
                margin: 0;
                cursor: pointer;
                font-size: 14px;
                line-height: 1;
                color: #000;
                font-family: 'Chicago', 'Geneva', monospace;
                display: flex;
                align-items: center;
                justify-content: center;
              "
              onmouseover="this.style.background='#D1D1D1'"
              onmouseout="this.style.background='transparent'"
            >
              ✕
            </button>
          </div>
          <div class="panel-content" style="
            overflow-y: auto;
            padding: 12px;
            max-height: 560px;
          ">
            <%= if @selected_node_info do %>
              <!-- Node info content -->
              <div class="node-info-display" style="font-size: 11px; color: #000; font-family: 'Chicago', 'Geneva', monospace;">
                <h4 style="margin: 0 0 8px 0; padding: 0; font-size: 13px; font-weight: bold; color: #000; border-bottom: 1px solid #666; padding-bottom: 4px;">
                  <%= Map.get(@selected_node_info, "name", "Unknown Node") %>
                </h4>
                <p style="margin: 0 0 12px 0; padding: 0; font-size: 10px; color: #666; text-transform: uppercase; letter-spacing: 0.5px;">
                  <%= Map.get(@selected_node_info, "category", "N/A") %>
                </p>

                <!-- ACTUAL INPUTS -->
                <section class="io-section" style="margin-bottom: 16px;">
                  <h5 style="margin: 0 0 6px 0; padding: 0; font-size: 10px; font-weight: bold; color: #000; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #CCC; padding-bottom: 2px;">
                    ACTUAL INPUTS:
                  </h5>
                  <%= if Enum.empty?(Map.get(@selected_node_info, "actual_inputs", [])) do %>
                    <p class="empty" style="margin: 4px 0; padding: 0; font-size: 10px; color: #999; font-style: italic;">None</p>
                  <% else %>
                    <ul style="margin: 4px 0; padding-left: 16px; list-style: none;">
                      <%= for input <- Map.get(@selected_node_info, "actual_inputs", []) do %>
                        <li style="margin-bottom: 4px; font-size: 10px;">
                          • <strong><%= Map.get(input, :resource, "connection") %></strong>
                          <span class="from" style="color: #666; font-size: 9px; margin-left: 4px;">
                            (from <%= Map.get(input, :from_node_name, "Unknown") %>)
                          </span>
                        </li>
                      <% end %>
                    </ul>
                  <% end %>
                </section>

                <!-- POTENTIAL INPUTS -->
                <section class="io-section" style="margin-bottom: 16px;">
                  <h5 style="margin: 0 0 6px 0; padding: 0; font-size: 10px; font-weight: bold; color: #000; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #CCC; padding-bottom: 2px;">
                    POTENTIAL INPUTS:
                  </h5>
                  <%= if Enum.empty?(Map.get(@selected_node_info, "potential_inputs", [])) do %>
                    <p class="empty" style="margin: 4px 0; padding: 0; font-size: 10px; color: #999; font-style: italic;">None available</p>
                  <% else %>
                    <ul style="margin: 4px 0; padding-left: 16px; list-style: none;">
                      <%= for input <- Map.get(@selected_node_info, "potential_inputs", []) do %>
                        <li class="potential" style="margin-bottom: 4px; font-size: 10px; color: #666;">
                          • <%= input %>
                        </li>
                      <% end %>
                    </ul>
                  <% end %>
                </section>

                <!-- ACTUAL OUTPUTS -->
                <section class="io-section" style="margin-bottom: 16px;">
                  <h5 style="margin: 0 0 6px 0; padding: 0; font-size: 10px; font-weight: bold; color: #000; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #CCC; padding-bottom: 2px;">
                    ACTUAL OUTPUTS:
                  </h5>
                  <%= if Enum.empty?(Map.get(@selected_node_info, "actual_outputs", [])) do %>
                    <p class="empty" style="margin: 4px 0; padding: 0; font-size: 10px; color: #999; font-style: italic;">None</p>
                  <% else %>
                    <ul style="margin: 4px 0; padding-left: 16px; list-style: none;">
                      <%= for output <- Map.get(@selected_node_info, "actual_outputs", []) do %>
                        <li style="margin-bottom: 4px; font-size: 10px;">
                          • <strong><%= Map.get(output, :resource, "connection") %></strong>
                          <span class="to" style="color: #666; font-size: 9px; margin-left: 4px;">
                            (to <%= Map.get(output, :to_node_name, "Unknown") %>)
                          </span>
                        </li>
                      <% end %>
                    </ul>
                  <% end %>
                </section>

                <!-- POTENTIAL OUTPUTS -->
                <section class="io-section" style="margin-bottom: 16px;">
                  <h5 style="margin: 0 0 6px 0; padding: 0; font-size: 10px; font-weight: bold; color: #000; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #CCC; padding-bottom: 2px;">
                    POTENTIAL OUTPUTS:
                  </h5>
                  <%= if Enum.empty?(Map.get(@selected_node_info, "potential_outputs", [])) do %>
                    <p class="empty" style="margin: 4px 0; padding: 0; font-size: 10px; color: #999; font-style: italic;">None available</p>
                  <% else %>
                    <ul style="margin: 4px 0; padding-left: 16px; list-style: none;">
                      <%= for output <- Map.get(@selected_node_info, "potential_outputs", []) do %>
                        <li class="potential" style="margin-bottom: 4px; font-size: 10px; color: #666;">
                          • <%= output %>
                        </li>
                      <% end %>
                    </ul>
                  <% end %>
                </section>
              </div>
            <% else %>
              <p style="font-size: 11px; color: #666; font-style: italic;">No node selected</p>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("node_info_clicked", %{"node_id" => node_id}, socket) do
    require Logger
    Logger.info("[NodeInfo] Info button clicked for node: #{node_id}")

    nodes = socket.assigns[:nodes] || %{}
    edges = socket.assigns[:edges] || %{}
    node_data = Map.get(nodes, node_id)

    if node_data do
      io_data = LivingWebHelpers.calculate_node_io_data(node_id, node_data, nodes, edges)

      enriched_node_data =
        node_data
        |> Map.put("id", node_id)
        |> Map.merge(io_data)

      {:noreply,
       socket
       |> assign(:selected_node_info, enriched_node_data)
       |> assign(:show_detail_panel, true)}
    else
      Logger.warning("[NodeInfo] Node not found: #{node_id}")
      {:noreply, put_flash(socket, :error, "Node not found")}
    end
  end

  @impl true
  def handle_event("close_detail_panel", _params, socket) do
    {:noreply, assign(socket, :show_detail_panel, false)}
  end

  @impl true
  def handle_event("node_selected", %{"node_id" => node_id, "node_type" => node_type, "node_label" => label}, socket) do
    IO.puts("Node selected: #{node_id} (#{node_type}) - #{label}")

    nodes = socket.assigns[:nodes] || %{}
    node_data = Map.get(nodes, node_id)

    linked_data = case node_data do
      %{"data" => %{"linked_type" => "user_plant", "linked_id" => plant_id}} when not is_nil(plant_id) ->
        case PlantingGuide.get_user_plant(socket.assigns.current_user.id, plant_id) do
          nil -> nil
          user_plant ->
            plant = PlantingGuide.get_plant!(user_plant.plant_id)
            %{type: "plant", user_plant: user_plant, plant: plant}
        end

      _ -> nil
    end

    socket = socket
    |> assign(:selected_living_web_node, %{
      id: node_id,
      type: node_type,
      label: label,
      linked_data: linked_data
    })
    |> assign(:show_harvest_panel, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_harvest_panel", _params, socket) do
    socket = socket
    |> assign(:show_harvest_panel, false)
    |> assign(:selected_living_web_node, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("node_added", %{"project_id" => project_id, "x" => x, "y" => y, "temp_id" => temp_id} = _params, socket) do
    Logger.info("Node added: project=#{project_id}, x=#{x}, y=#{y}")

    nodes = socket.assigns[:nodes] || %{}
    project = Systems.get_project!(project_id)

    nodes =
      Map.put(nodes, temp_id, %{
        "name" => project.name,
        "category" => project.category,
        "project_id" => project_id,
        "x" => x,
        "y" => y,
        "instance_scale" => 1.0
      })

    socket = assign(socket, :nodes, nodes)

    node_data = %{
      id: temp_id,
      type: "default",
      position: %{x: x, y: y},
      data: %{
        label: "#{project.icon_name} #{project.name}",
        project_id: project_id,
        inputs: [],
        outputs: []
      }
    }

    socket = push_event(socket, "node_added_success", %{node: node_data})
    socket = save_state_to_history(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_event("composite_node_added", %{"composite_id" => composite_id_str, "x" => x, "y" => y, "temp_id" => temp_id} = _params, socket) do
    Logger.info("Composite node added: composite=#{composite_id_str}, x=#{x}, y=#{y}")

    with {:ok, composite_id} <- LivingWebHelpers.parse_integer(composite_id_str),
         composite when not is_nil(composite) <- LivingWebHelpers.get_composite_safe(composite_id) do

      node_id = Diagrams.generate_composite_node_id(composite_id)

      node_data = %{
        "composite_system_id" => composite_id,
        "x" => x,
        "y" => y,
        "is_expanded" => false,
        "instance_scale" => 1.0
      }

      nodes = socket.assigns[:nodes] || %{}
      updated_nodes = Map.put(nodes, node_id, node_data)
      diagram = socket.assigns[:diagram]

      updated_socket =
        case Diagrams.update_diagram(diagram, %{nodes: updated_nodes}) do
          {:ok, updated_diagram} ->
            socket
            |> assign(:diagram, updated_diagram)
            |> assign(:nodes, updated_nodes)
            |> push_event("composite_node_added_success", %{
              temp_id: temp_id,
              node_id: node_id,
              composite_id: composite.id,
              name: composite.name,
              description: composite.description,
              icon_name: composite.icon_name,
              external_inputs: composite.external_inputs,
              external_outputs: composite.external_outputs,
              position: %{x: x, y: y}
            })
            |> save_state_to_history()

          {:error, _changeset} ->
            socket
            |> put_flash(:error, "Failed to add composite node")
        end

      {:noreply, updated_socket}
    else
      nil ->
        {:noreply, put_flash(socket, :error, "Composite system not found")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Invalid composite ID")}
    end
  end

  @impl true
  def handle_event("nodes_selected", %{"node_ids" => ids}, socket) do
    require Logger
    Logger.info("[SaveAsSystem] Nodes selected: #{inspect(ids)}")
    {:noreply, assign(socket, selected_nodes: ids)}
  end

  @impl true
  def handle_event("show_save_system_dialog", _params, socket) do
    require Logger
    selected_count = length(socket.assigns[:selected_nodes] || [])
    Logger.info("[SaveAsSystem] Show dialog clicked - #{selected_count} nodes selected")

    if selected_count >= 2 do
      {:noreply, assign(socket, show_system_dialog: true)}
    else
      {:noreply, put_flash(socket, :error, "Please select at least 2 nodes")}
    end
  end

  @impl true
  def handle_event("hide_system_dialog", _params, socket) do
    {:noreply, assign(socket, show_system_dialog: false)}
  end

  @impl true
  def handle_event("save_as_system", %{"system_name" => name}, socket) do
    require Logger
    Logger.info("[SaveAsSystem] Saving composite system - name: #{name}")

    current_user = socket.assigns[:current_user]
    user_id = if current_user, do: current_user.id, else: nil
    selected_nodes = socket.assigns[:selected_nodes] || []
    nodes = socket.assigns[:nodes] || %{}
    edges = socket.assigns[:edges] || %{}
    diagram = socket.assigns[:diagram]

    if length(selected_nodes) < 2 do
      {:noreply, put_flash(socket, :error, "Please select at least 2 nodes")}
    else
      case Diagrams.create_composite_system(user_id, name, selected_nodes, nodes, edges, diagram.id) do
        {:ok, composite} ->
          Logger.info("[SaveAsSystem] System created: #{composite.id}")

          composite_systems = socket.assigns[:composite_systems] || []
          updated_composite_systems = [composite | composite_systems]

          {:noreply,
           socket
           |> assign(:composite_systems, updated_composite_systems)
           |> assign(:show_system_dialog, false)
           |> assign(:selected_nodes, [])
           |> put_flash(:info, "System '#{name}' created successfully!")
           |> push_event("system_created_success", %{
             id: composite.id,
             name: composite.name,
             icon_name: composite.icon_name
           })}

        {:error, reason} ->
          Logger.error("[SaveAsSystem] Failed to create system: #{inspect(reason)}")
          {:noreply, put_flash(socket, :error, "Failed to create system: #{inspect(reason)}")}
      end
    end
  end

  @impl true
  def handle_event("expand_system", %{"node_id" => node_id}, socket) do
    handle_event("expand_composite_node", %{"node_id" => node_id}, socket)
  end

  @impl true
  def handle_event("collapse_system", %{"node_id" => node_id}, socket) do
    handle_event("collapse_composite_node", %{"node_id" => node_id}, socket)
  end

  @impl true
  def handle_event("expand_composite_node", %{"node_id" => node_id}, socket) do
    require Logger
    Logger.info("[CompositeExpand] Event received - node_id: #{node_id}")

    nodes = socket.assigns[:nodes] || %{}
    edges = socket.assigns[:edges] || %{}
    diagram = socket.assigns[:diagram]
    projects = socket.assigns[:projects] || []
    composite_systems = socket.assigns[:composite_systems] || []

    node_data = Map.get(nodes, node_id)

    {node_data, actual_node_id} = if is_nil(node_data) and not String.starts_with?(node_id, "expanded_") do
      found = Enum.find(nodes, fn {_expanded_id, node} ->
        Map.get(node, "original_node_id") == node_id
      end)

      case found do
        {expanded_id, expanded_node} -> {expanded_node, expanded_id}
        nil -> {nil, node_id}
      end
    else
      {node_data, node_id}
    end

    if is_nil(node_data) do
      {:noreply, put_flash(socket, :error, "Node not found")}
    else
      case Diagrams.node_type(node_data) do
        {:composite, composite_id} ->
          composite = Enum.find(composite_systems, &(&1.id == composite_id))

          if is_nil(composite) do
            {:noreply, put_flash(socket, :error, "Composite system not found")}
          else
            is_expanded = Diagrams.node_expanded?(node_data)

            if !is_expanded do
              composite_x = Map.get(node_data, "x", 0)
              composite_y = Map.get(node_data, "y", 0)

              internal_node_ids = composite.internal_node_ids || []
              stored_nodes = composite.internal_nodes_data || %{}
              stored_edges = composite.internal_edges_data || %{}

              parent_nodes = if map_size(stored_nodes) > 0 do
                stored_nodes
              else
                parent_diagram = if composite.parent_diagram_id do
                  Diagrams.get_diagram!(composite.parent_diagram_id)
                else
                  diagram
                end
                parent_diagram.nodes || %{}
              end

              parent_edges = if map_size(stored_edges) > 0 do
                stored_edges
              else
                parent_diagram = if composite.parent_diagram_id do
                  Diagrams.get_diagram!(composite.parent_diagram_id)
                else
                  diagram
                end
                parent_diagram.edges || %{}
              end

              {expanded_nodes, id_mapping} =
                internal_node_ids
                |> Enum.reduce({nodes, %{}}, fn internal_id, {acc_nodes, id_map} ->
                  case Map.get(parent_nodes, internal_id) do
                    nil -> {acc_nodes, id_map}
                    internal_node ->
                      internal_composite_id = Map.get(internal_node, "composite_system_id")
                      expanded_id = Diagrams.generate_expanded_node_id(actual_node_id, internal_id)

                      orig_x = Map.get(internal_node, "x", 0)
                      orig_y = Map.get(internal_node, "y", 0)
                      rel_pos = Map.get(internal_node, "relative_position") || Map.get(internal_node, "position", %{})
                      rel_x = Map.get(rel_pos, "x")
                      rel_y = Map.get(rel_pos, "y")

                      final_x = if rel_x, do: composite_x + rel_x, else: orig_x
                      final_y = if rel_y, do: composite_y + rel_y, else: orig_y

                      expanded_node = internal_node
                      |> Map.put("x", final_x)
                      |> Map.put("y", final_y)
                      |> Map.put("parent_composite_id", actual_node_id)
                      |> Map.put("original_node_id", internal_id)
                      |> then(fn node ->
                        if internal_composite_id do
                          Map.put(node, "composite_system_id", internal_composite_id)
                        else
                          node
                        end
                      end)
                      |> Map.delete("relative_position")
                      |> Map.delete("position")

                      {Map.put(acc_nodes, expanded_id, expanded_node), Map.put(id_map, internal_id, expanded_id)}
                  end
                end)

              updated_composite_node = Map.put(node_data, "is_expanded", true)
              updated_nodes = Map.put(expanded_nodes, actual_node_id, updated_composite_node)

              internal_edge_ids = composite.internal_edge_ids || []
              expanded_edges =
                internal_edge_ids
                |> Enum.reduce(edges, fn edge_id, acc_edges ->
                  case Map.get(parent_edges, edge_id) do
                    nil -> acc_edges
                    edge_data ->
                      source_id = Map.get(edge_data, "source_id") || Map.get(edge_data, "source")
                      target_id = Map.get(edge_data, "target_id") || Map.get(edge_data, "target")

                      expanded_source_id = Map.get(id_mapping, source_id, Diagrams.generate_expanded_node_id(actual_node_id, source_id))
                      expanded_target_id = Map.get(id_mapping, target_id, Diagrams.generate_expanded_node_id(actual_node_id, target_id))

                      expanded_edge_id = "expanded_#{actual_node_id}_#{edge_id}"

                      expanded_edge = edge_data
                      |> Map.put("source_id", expanded_source_id)
                      |> Map.put("target_id", expanded_target_id)
                      |> Map.put("parent_composite_id", actual_node_id)
                      |> Map.delete("source")
                      |> Map.delete("target")

                      Map.put(acc_edges, expanded_edge_id, expanded_edge)
                  end
                end)

              expanded = socket.assigns[:expanded_composites] || []
              expanded = [actual_node_id | expanded] |> Enum.uniq()
              base_id = case Regex.run(~r/^expanded_.*?_(.+)$/, actual_node_id) do
                [_, base] -> base
                _ -> String.replace(actual_node_id, ~r/^expanded_.*?_/, "")
              end
              expanded = [base_id | expanded] |> Enum.uniq()

              updated_socket =
                case Diagrams.update_diagram(diagram, %{nodes: updated_nodes, edges: expanded_edges}) do
                  {:ok, updated_diagram} ->
                    enriched_nodes = LivingWebHelpers.enrich_nodes_with_project_data(updated_nodes, projects, composite_systems)
                    rerouted_edges = LivingWebHelpers.reroute_edges_for_expanded_composite(expanded_edges, actual_node_id, enriched_nodes)
                    resolved_edges = LivingWebHelpers.resolve_connection_endpoints(rerouted_edges, enriched_nodes, expanded)

                    visible_nodes = Enum.reject(enriched_nodes, fn {node_id, _node} ->
                      node_id in expanded
                    end)
                    |> Enum.into(%{})

                    socket
                    |> assign(:diagram, updated_diagram)
                    |> assign(:nodes, updated_nodes)
                    |> assign(:edges, resolved_edges)
                    |> assign(:expanded_composites, expanded)
                    |> push_event("composite_expanded_success", %{
                      node_id: actual_node_id,
                      nodes: visible_nodes,
                      edges: resolved_edges
                    })
                    |> push_event("edges_updated", %{edges: resolved_edges})
                    |> push_event("nodes_updated", %{nodes: visible_nodes})
                    |> put_flash(:info, "System expanded successfully!")
                    |> save_state_to_history()

                  {:error, changeset} ->
                    socket
                    |> put_flash(:error, "Failed to expand composite node: #{inspect(changeset.errors)}")
                end

              {:noreply, updated_socket}
            else
              {:noreply, socket}
            end
          end

        _ ->
          {:noreply, put_flash(socket, :error, "Node is not a composite")}
      end
    end
  end

  @impl true
  def handle_event("collapse_composite_node", %{"node_id" => node_id}, socket) do
    require Logger
    Logger.info("[CompositeCollapse] Event received - node_id: #{node_id}")

    nodes = socket.assigns[:nodes] || %{}
    edges = socket.assigns[:edges] || %{}
    diagram = socket.assigns[:diagram]
    projects = socket.assigns[:projects] || []
    composite_systems = socket.assigns[:composite_systems] || []

    node_data = Map.get(nodes, node_id)

    {node_data, actual_node_id} = if is_nil(node_data) and not String.starts_with?(node_id, "expanded_") do
      found = Enum.find(nodes, fn {_expanded_id, node} ->
        Map.get(node, "original_node_id") == node_id
      end)

      case found do
        {expanded_id, expanded_node} -> {expanded_node, expanded_id}
        nil -> {nil, node_id}
      end
    else
      {node_data, node_id}
    end

    if is_nil(node_data) do
      {:noreply, put_flash(socket, :error, "Node not found")}
    else
      if Diagrams.composite_node?(node_data) && Diagrams.node_expanded?(node_data) do
        updated_nodes =
          nodes
          |> Enum.reject(fn {id, node} ->
            node_parent = Map.get(node, "parent_composite_id")
            is_direct_child = node_parent == actual_node_id
            is_direct_child
          end)
          |> Enum.into(%{})

        updated_edges =
          edges
          |> Enum.reject(fn {edge_id, edge} ->
            edge_parent = Map.get(edge, "parent_composite_id")
            is_direct_child = edge_parent == actual_node_id
            is_direct_child
          end)
          |> Enum.into(%{})

        expanded = socket.assigns[:expanded_composites] || []
        expanded = List.delete(expanded, actual_node_id)
        base_id = case Regex.run(~r/^expanded_.*?_(.+)$/, actual_node_id) do
          [_, base] -> base
          _ -> String.replace(actual_node_id, ~r/^expanded_.*?_/, "")
        end
        expanded = List.delete(expanded, base_id)

        collapsed_node = Map.put(node_data, "is_expanded", false)
        final_nodes = Map.put(updated_nodes, actual_node_id, collapsed_node)

        updated_socket =
          case Diagrams.update_diagram(diagram, %{nodes: final_nodes, edges: updated_edges}) do
            {:ok, updated_diagram} ->
              enriched_nodes = LivingWebHelpers.enrich_nodes_with_project_data(final_nodes, projects, composite_systems)
              rerouted_edges = LivingWebHelpers.reroute_edges_for_collapsed_composite(updated_edges, actual_node_id, enriched_nodes)
              resolved_edges = LivingWebHelpers.resolve_connection_endpoints(rerouted_edges, enriched_nodes, expanded)

              visible_nodes = Enum.reject(enriched_nodes, fn {node_id, _node} ->
                node_id in expanded
              end)
              |> Enum.into(%{})

              socket
              |> assign(:diagram, updated_diagram)
              |> assign(:nodes, final_nodes)
              |> assign(:edges, resolved_edges)
              |> assign(:expanded_composites, expanded)
              |> push_event("composite_collapsed_success", %{
                node_id: actual_node_id,
                nodes: visible_nodes,
                edges: resolved_edges
              })
              |> push_event("edges_updated", %{edges: resolved_edges})
              |> push_event("nodes_updated", %{nodes: visible_nodes})
              |> save_state_to_history()

            {:error, _changeset} ->
              socket
              |> put_flash(:error, "Failed to collapse composite node")
          end

        {:noreply, updated_socket}
      else
        {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("node_moved", %{"node_id" => node_id, "position_x" => x_str, "position_y" => y_str}, socket) do
    with {:ok, x} <- LivingWebHelpers.parse_integer(x_str),
         {:ok, y} <- LivingWebHelpers.parse_integer(y_str) do

      nodes = socket.assigns[:nodes] || %{}
      diagram = socket.assigns[:diagram]

      if Map.has_key?(nodes, node_id) do
        updated_node = Map.get(nodes, node_id)
        |> Map.put("x", x)
        |> Map.put("y", y)

        updated_nodes = Map.put(nodes, node_id, updated_node)

        updated_socket = case Diagrams.update_diagram(diagram, %{nodes: updated_nodes}) do
          {:ok, updated_diagram} ->
             socket
             |> assign(:diagram, updated_diagram)
             |> assign(:nodes, updated_nodes)
          _ -> socket
        end

        {:noreply, updated_socket}
      else
        {:noreply, socket}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("nodes_deleted", %{"node_ids" => node_ids}, socket) do
    IO.puts("🗑️ Deleting nodes: #{inspect(node_ids)}")

    existing_nodes = socket.assigns[:nodes] || %{}
    existing_edges = socket.assigns[:edges] || %{}
    diagram = socket.assigns.diagram

    updated_nodes = Enum.reduce(node_ids, existing_nodes, fn node_id, acc ->
      Map.delete(acc, node_id)
    end)

    node_ids_set = MapSet.new(node_ids)
    updated_edges = Enum.filter(existing_edges, fn {_edge_id, edge_data} ->
      source_id = Map.get(edge_data, "source_id") || Map.get(edge_data, :source_id)
      target_id = Map.get(edge_data, "target_id") || Map.get(edge_data, :target_id)

      not MapSet.member?(node_ids_set, source_id) and not MapSet.member?(node_ids_set, target_id)
    end)
    |> Enum.into(%{})

    {socket, persisted_nodes, persisted_edges} =
      case diagram do
        nil -> {socket, updated_nodes, updated_edges}
        d ->
          case Diagrams.update_diagram(d, %{nodes: updated_nodes, edges: updated_edges}) do
            {:ok, d2} -> {socket |> assign(:diagram, d2), updated_nodes, updated_edges}
            _ -> {socket, updated_nodes, updated_edges}
          end
      end

    socket =
      socket
      |> assign(:nodes, persisted_nodes)
      |> assign(:edges, persisted_edges)

    {:noreply, push_event(socket, "nodes_deleted_success", %{node_ids: node_ids})}
  end

  @impl true
  def handle_event("nodes_hidden", %{"node_ids" => node_ids}, socket) do
    require Logger
    Logger.info("[HideNodes] Hiding nodes: #{inspect(node_ids)}")

    existing_nodes = socket.assigns[:nodes] || %{}
    existing_edges = socket.assigns[:edges] || %{}
    diagram = socket.assigns.diagram

    nodes_to_hide = Enum.reduce(node_ids, MapSet.new(), fn node_id, acc ->
      node_data = Map.get(existing_nodes, node_id)

      {node_data, actual_node_id} = if is_nil(node_data) and not String.starts_with?(node_id, "expanded_") do
        found = Enum.find(existing_nodes, fn {_expanded_id, node} ->
          Map.get(node, "original_node_id") == node_id
        end)

        case found do
          {expanded_id, expanded_node} -> {expanded_node, expanded_id}
          nil -> {nil, node_id}
        end
      else
        {node_data, node_id}
      end

      if is_nil(node_data) do
        acc
      else
        if Diagrams.composite_node?(node_data) && Diagrams.node_expanded?(node_data) do
          internal_node_ids = existing_nodes
          |> Enum.filter(fn {_id, node} ->
            Map.get(node, "parent_composite_id") == actual_node_id
          end)
          |> Enum.map(fn {id, _node} -> id end)

          Enum.reduce(internal_node_ids, MapSet.put(acc, actual_node_id), fn internal_id, inner_acc ->
            MapSet.put(inner_acc, internal_id)
          end)
        else
          MapSet.put(acc, actual_node_id)
        end
      end
    end)
    |> MapSet.to_list()

    updated_nodes = Enum.into(existing_nodes, %{}, fn {id, node} ->
      if id in nodes_to_hide do
        {id, Map.put(node, "hidden", true)}
      else
        {id, node}
      end
    end)

    updated_edges = Enum.into(existing_edges, %{}, fn {edge_id, edge} ->
      source_id = Map.get(edge, "source_id") || Map.get(edge, "source")
      target_id = Map.get(edge, "target_id") || Map.get(edge, "target")

      if source_id in nodes_to_hide || target_id in nodes_to_hide do
        {edge_id, Map.put(edge, "hidden", true)}
      else
        {edge_id, edge}
      end
    end)

    socket =
      case diagram do
        nil -> socket
        d ->
          case Diagrams.update_diagram(d, %{nodes: updated_nodes, edges: updated_edges}) do
            {:ok, d2} -> socket |> assign(:diagram, d2)
            _ -> socket
          end
      end
      |> assign(:nodes, updated_nodes)
      |> assign(:edges, updated_edges)

    {:noreply, push_event(socket, "nodes_hidden_success", %{node_ids: nodes_to_hide})}
  end

  @impl true
  def handle_event("show_all_nodes", _params, socket) do
    require Logger
    Logger.info("[ShowAll] Showing all hidden nodes and edges")

    existing_nodes = socket.assigns[:nodes] || %{}
    existing_edges = socket.assigns[:edges] || %{}
    diagram = socket.assigns.diagram

    updated_nodes = Enum.into(existing_nodes, %{}, fn {id, node} ->
      {id, Map.delete(node, "hidden")}
    end)

    updated_edges = Enum.into(existing_edges, %{}, fn {edge_id, edge} ->
      {edge_id, Map.delete(edge, "hidden")}
    end)

    socket =
      case diagram do
        nil -> socket
        d ->
          case Diagrams.update_diagram(d, %{nodes: updated_nodes, edges: updated_edges}) do
            {:ok, d2} -> socket |> assign(:diagram, d2)
            _ -> socket
          end
      end
      |> assign(:nodes, updated_nodes)
      |> assign(:edges, updated_edges)

    {:noreply, push_event(socket, "show_all_success", %{nodes: updated_nodes, edges: updated_edges})}
  end

  @impl true
  def handle_event("clear_canvas", _params, socket) do
    IO.puts("🧹 Clearing entire canvas")

    diagram = socket.assigns.diagram
    updated_nodes = %{}

    socket =
      case diagram do
        nil -> socket
        d ->
          case Diagrams.update_diagram(d, %{nodes: updated_nodes}) do
            {:ok, d2} -> socket |> assign(:diagram, d2)
            _ -> socket
          end
      end
      |> assign(:nodes, updated_nodes)

    {:noreply, push_event(socket, "canvas_cleared", %{})}
  end

  @impl true
  def handle_event("edge_added", %{"source_id" => source_id, "target_id" => target_id} = params, socket) do
    source_handle = Map.get(params, "source_handle")
    target_handle = Map.get(params, "target_handle")
    label = Map.get(params, "label")
    edge_id = Map.get(params, "edge_id") || ("edge_" <> Base.encode16(:crypto.strong_rand_bytes(6), case: :lower))
    diagram = socket.assigns.diagram
    edges = socket.assigns.edges || %{}

    resource_type = source_handle || target_handle || label || "connection"

    new_edge = %{
      "source_id" => source_id,
      "target_id" => target_id,
      "resource_type" => resource_type,
      "connection_type" => "actual"
    }
    |> LivingWebHelpers.maybe_add_port_info("source_handle", source_handle)
    |> LivingWebHelpers.maybe_add_port_info("target_handle", target_handle)
    |> LivingWebHelpers.maybe_add_port_info("label", label)

    updated_edges = Map.put(edges, edge_id, new_edge)

    updated_socket =
      case diagram do
        nil -> assign(socket, :edges, updated_edges)
        d ->
          case Diagrams.update_diagram(d, %{edges: updated_edges}) do
            {:ok, d2} -> socket |> assign(:diagram, d2) |> assign(:edges, updated_edges)
            _ -> socket
          end
      end

    potential_edges = LivingWebHelpers.detect_potential_connections(socket.assigns[:nodes] || %{}, updated_edges)
    updated_socket =
      updated_socket
      |> assign(:potential_edges, potential_edges)
      |> push_event("edge_added_success", %{edges: updated_edges})
      |> push_event("potential_edges_updated", %{potential_edges: potential_edges})
      |> save_state_to_history()

    {:noreply, updated_socket}
  end

  @impl true
  def handle_event("create_connection", %{"source_id" => source_id, "target_id" => target_id} = params, socket) do
    source_handle = Map.get(params, "source_handle")
    target_handle = Map.get(params, "target_handle")
    edge_id = Map.get(params, "edge_id") || ("edge_" <> Base.encode16(:crypto.strong_rand_bytes(6), case: :lower))
    diagram = socket.assigns.diagram
    edges = socket.assigns.edges || %{}

    resource_type = source_handle || target_handle || "connection"

    new_edge = %{
      "source_id" => source_id,
      "target_id" => target_id,
      "resource_type" => resource_type,
      "connection_type" => "actual"
    }
    |> LivingWebHelpers.maybe_add_port_info("source_handle", source_handle)
    |> LivingWebHelpers.maybe_add_port_info("target_handle", target_handle)

    updated_edges = Map.put(edges, edge_id, new_edge)

    updated_socket =
      case diagram do
        nil -> assign(socket, :edges, updated_edges)
        d ->
          case Diagrams.update_diagram(d, %{edges: updated_edges}) do
            {:ok, d2} -> socket |> assign(:diagram, d2) |> assign(:edges, updated_edges)
            _ -> socket
          end
      end

    potential_edges = LivingWebHelpers.detect_potential_connections(socket.assigns[:nodes] || %{}, updated_edges)
    updated_socket =
      updated_socket
      |> assign(:potential_edges, potential_edges)
      |> push_event("edge_added_success", %{edges: updated_edges})
      |> push_event("potential_edges_updated", %{potential_edges: potential_edges})
      |> save_state_to_history()

    {:noreply, updated_socket}
  end

  @impl true
  def handle_event("edges_deleted", %{"edge_ids" => edge_ids}, socket) do
    IO.puts("🗑️ Deleting edges: #{inspect(edge_ids)}")

    existing_edges = socket.assigns[:edges] || %{}
    diagram = socket.assigns.diagram

    updated_edges = Enum.reduce(edge_ids, existing_edges, fn edge_id, acc ->
      Map.delete(acc, edge_id)
    end)

    socket =
      case diagram do
        nil -> socket
        d ->
          case Diagrams.update_diagram(d, %{edges: updated_edges}) do
            {:ok, d2} -> socket |> assign(:diagram, d2)
            _ -> socket
          end
      end
      |> assign(:edges, updated_edges)

    potential_edges = LivingWebHelpers.detect_potential_connections(socket.assigns[:nodes] || %{}, updated_edges)
    socket =
      socket
      |> assign(:potential_edges, potential_edges)
      |> push_event("edges_deleted_success", %{edge_ids: edge_ids})
      |> push_event("potential_edges_updated", %{potential_edges: potential_edges})
      |> save_state_to_history()

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_suggestions", _params, socket) do
    nodes = socket.assigns.nodes || %{}
    edges = socket.assigns.edges || %{}
    projects = socket.assigns.projects || []

    suggestions = Suggestions.generate_suggestions(nodes, edges, projects)

    {:noreply, push_event(socket, "suggestions_loaded", %{suggestions: suggestions})}
  end

  @impl true
  def handle_event("apply_suggestion", %{"type" => "connection", "action" => action}, socket) do
    source_id = action["source_id"]
    target_id = action["target_id"]

    # Reuse edge_added handler logic
    edge_id = "edge_" <> Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)
    diagram = socket.assigns.diagram
    edges = socket.assigns.edges || %{}

    new_edge = %{
      "source_id" => source_id,
      "target_id" => target_id
    }

    updated_edges = Map.put(edges, edge_id, new_edge)

    updated_socket =
      case diagram do
        nil -> assign(socket, :edges, updated_edges)
        d ->
          case Diagrams.update_diagram(d, %{edges: updated_edges}) do
            {:ok, d2} -> socket |> assign(:diagram, d2) |> assign(:edges, updated_edges)
            _ -> socket
          end
      end

    potential_edges = LivingWebHelpers.detect_potential_connections(socket.assigns[:nodes] || %{}, updated_edges)

    updated_socket =
      updated_socket
      |> assign(:potential_edges, potential_edges)
      |> push_event("edge_added_success", %{edges: updated_edges})
      |> push_event("potential_edges_updated", %{potential_edges: potential_edges})
      |> put_flash(:info, "Suggestion applied: connection created")
      |> save_state_to_history()

    {:noreply, updated_socket}
  end

  def handle_event("apply_suggestion", _params, socket) do
    {:noreply, put_flash(socket, :info, "Suggestion type not yet implemented")}
  end

  defp save_state_to_history(socket) do
    history_stack = socket.assigns[:history_stack] || []
    history_index = socket.assigns[:history_index] || -1
    max_history = socket.assigns[:max_history] || 50

    snapshot = %{
      nodes: socket.assigns[:nodes] || %{},
      edges: socket.assigns[:edges] || %{},
      timestamp: System.system_time(:millisecond)
    }

    history_stack = Enum.take(history_stack, history_index + 1)
    history_stack = [snapshot | history_stack]
    history_stack = Enum.take(history_stack, max_history)

    socket
    |> assign(:history_stack, history_stack)
    |> assign(:history_index, 0)
  end
end
