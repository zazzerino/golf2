defmodule GolfWeb.GameLive do
  use GolfWeb, :live_view

  def render(assigns) do
    ~H"""
    <script src="https://pixijs.download/release/pixi.js"></script>
    <h2>Game <%= @game_id %></h2>
    <div id="game-container" phx-update="ignore"></div>
    """
  end

  def mount(%{"game_id" => game_id}, assigns, socket) do
    IO.inspect(game_id)
    IO.inspect(assigns)
    {:ok, assign(socket, :game_id, game_id)}
  end
end
