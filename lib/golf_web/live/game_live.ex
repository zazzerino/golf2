defmodule GolfWeb.GameLive do
  use GolfWeb, :live_view
  alias Golf.GamesDb

  @impl true
  def render(assigns) do
    ~H"""
    <script src="https://pixijs.download/release/pixi.js">
    </script>

    <h2>Game <%= @game.id %></h2>
    <div id="game-container" phx-hook="GameCanvas" phx-update="ignore"></div>

    <.button :if={@game.status == :init} phx-click="start_game">
      Start Game
    </.button>
    """
  end

  @impl true
  def mount(%{"game_id" => game_id}, _assigns, socket) do
    with {game_id, _} <- Integer.parse(game_id),
         game when is_struct(game) <- GamesDb.get_game(game_id) do
      Phoenix.PubSub.subscribe(Golf.PubSub, topic(game_id))

      {:ok,
       socket
       |> assign(:page_title, "Game #{game_id}")
       |> assign(:game, game)
       |> push_event("game-loaded", %{"game" => game})}
    else
      _ ->
        {:ok,
         socket |> put_flash(:error, "Game \"#{game_id}\" not found.") |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("start_game", _value, socket) do
    game = socket.assigns.game
    {:ok, _} = GamesDb.start_game(game)
    Phoenix.PubSub.broadcast(Golf.PubSub, topic(game.id), :game_started)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:game_started, socket) do
    IO.puts("Game started...")
    {:noreply, socket}
  end

  defp topic(game_id), do: "game:#{game_id}"
end
