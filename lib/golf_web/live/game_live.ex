defmodule GolfWeb.GameLive do
  use GolfWeb, :live_view
  alias Golf.Games

  def render(assigns) do
    ~H"""
    <script src="https://pixijs.download/release/pixi.js">
    </script>
    <h2>Game <%= @game_id %></h2>
    <div id="game-canvas" phx-hook="GameCanvas" phx-update="ignore"></div>
    """
  end

  def mount(%{"game_id" => game_id}, assigns, socket) do
    with {game_id, _} <- Integer.parse(game_id),
         game when is_struct(game) <- Games.get_game(game_id) do
      Phoenix.PubSub.subscribe(Golf.PubSub, "game:#{game_id}")

      {:ok,
       socket
       |> assign(:page_title, "Game #{game_id}")
       |> assign(:game_id, game_id)
       |> push_event("game-loaded", %{"game" => game})}
    else
      _ ->
        {:ok, socket |> redirect(to: ~p"/") |> put_flash(:error, "Game #{game_id} not found.")}
    end
  end
end
