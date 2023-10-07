defmodule GolfWeb.GameLive do
  use GolfWeb, :live_view

  def render(assigns) do
    ~H"""
    <script src="https://pixijs.download/release/pixi.js">
    </script>

    <h2>Game</h2>

    <div id="game-container" phx-update="ignore"></div>
    """
  end

  def mount(_params, _assigns, socket) do
    {:ok, socket}
  end
end
