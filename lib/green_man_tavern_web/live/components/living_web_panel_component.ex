defmodule GreenManTavernWeb.LivingWebPanelComponent do
  use GreenManTavernWeb, :live_component

  alias GreenManTavernWeb.RackComponent

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="living-web-content h-full w-full">
      <.live_component
        module={RackComponent}
        id="rack-view"
        current_user={@current_user}
      />
    </div>
    """
  end
end
