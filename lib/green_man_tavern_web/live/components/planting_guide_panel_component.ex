defmodule GreenManTavernWeb.PlantingGuidePanelComponent do
  use GreenManTavernWeb, :live_component
  
  alias GreenManTavern.PlantingGuide
  alias GreenManTavern.PlantingGuide.{Plant, CompanionRelationship}
  alias GreenManTavern.Repo
  require Logger
  
  @impl true
  def mount(socket) do
    {:ok, socket}
  end
  
  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)
    
    # Initialize state on first load
    socket = if socket.assigns[:initialized] do
      socket
    else
      initialize_planting_guide(socket)
    end
    
    {:ok, socket}
  end
  
  defp initialize_planting_guide(socket) do
    user_id = socket.assigns.current_user.id
    
    # Load all cities
    cities = PlantingGuide.list_cities()
    
    # Load all plants
    all_plants = PlantingGuide.list_plants()
    
    # Load user's plants
    user_plants = PlantingGuide.list_user_plants(user_id)
    
    # Generate calendars for current year
    calendars = generate_all_calendars()
    
    socket
    |> assign(:initialized, true)
    |> assign(:cities, cities)
    |> assign(:all_plants, all_plants)
    |> assign(:user_plants, user_plants)
    |> assign(:calendars, calendars)
    |> assign(:selected_city_id, nil)
    |> assign(:selected_city, nil)
    |> assign(:selected_climate_zone, nil)
    |> assign(:selected_day, nil)
    |> assign(:selected_day_range_start, nil)
    |> assign(:selected_day_range_end, nil)
    |> assign(:planting_method, :seeds)
    |> assign(:selected_plant_type, "all")
    |> assign(:selected_difficulty, "all")
    |> assign(:filtered_plants, [])
    |> assign(:selected_plant, nil)
    |> assign(:show_plant_modal, false)
    |> apply_filters()
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div>Planting Guide Component - Under Construction</div>
    """
  end
  
  # Helper functions will be added here
  
  defp generate_all_calendars(year \\ nil) do
    year = year || Date.utc_today().year
    
    1..12
    |> Enum.map(fn month_num ->
      generate_calendar_month(month_num, year)
    end)
  end
  
  defp generate_calendar_month(month_num, year) do
    # This function needs to be copied from DualPanelLive
    # For now, return a placeholder
    %{
      month_number: month_num,
      month_name: month_name(month_num),
      year: year,
      first_day_of_week: 1,
      days: []
    }
  end
  
  defp month_name(1), do: "January"
  defp month_name(2), do: "February"
  defp month_name(3), do: "March"
  defp month_name(4), do: "April"
  defp month_name(5), do: "May"
  defp month_name(6), do: "June"
  defp month_name(7), do: "July"
  defp month_name(8), do: "August"
  defp month_name(9), do: "September"
  defp month_name(10), do: "October"
  defp month_name(11), do: "November"
  defp month_name(12), do: "December"
  
  defp apply_filters(socket) do
    # Placeholder - will implement full filtering logic
    assign(socket, :filtered_plants, socket.assigns[:all_plants] || [])
  end
end
