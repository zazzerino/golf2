defmodule GolfWeb.GameLive do
  use GolfWeb, :live_view

  alias Golf.GamesDb
  alias GolfWeb.UserAuth

  @impl true
  def mount(%{"game_id" => game_id}, session, socket) do
    with {:get_token, token} when is_binary(token) <- {:get_token, session["user_token"]},
         {:ok, _, user_id} <- UserAuth.verify(token),
         {game_id, _} <- Integer.parse(game_id),
         game when is_struct(game) <- GamesDb.get_game(game_id),
         :ok <- subscribe(game_id) do
      {:ok,
       socket
       |> push_event("game-loaded", %{"game" => game})
       |> assign(user_id: user_id, page_title: "Game #{game_id}")
       |> assign(game_data(game, user_id))}
    else
      _ ->
        {:ok, socket |> redirect(to: ~p"/")}
    end
  end

  defp game_data(game, user_id) do
    game_is_init? = game.status == :init

    [
      game: game,
      can_start_game?: game_is_init? and user_id == game.host_id,
      can_join_game?: game_is_init? and not user_is_player?(user_id, game.players)
    ]
  end

  @impl true
  def handle_event("start_game", _value, socket) do
    {:ok, game} = GamesDb.start_game(socket.assigns.game)
    broadcast_from(game.id, {:game_started, game})

    {:noreply,
     socket
     |> push_event("game-started", %{"game" => game})
     |> assign(game: game, can_start_game?: false)}
  end

  @impl true
  def handle_event("join_game", _value, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:load_game, game_id}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:game_started, game}, socket) do
    {:noreply,
     socket
     |> push_event("game-started", %{"game" => game})
     |> assign(game: game, can_start_game?: false)}
  end

  @impl true
  def handle_info({:player_joined, game, user_id}, socket) do
    can_join_game? = socket.assigns.user_id != user_id and socket.assigns.can_join_game?

    {:noreply,
     socket
     |> push_event("player-joined", %{"game" => game, "user_id" => user_id})
     |> assign(game: game, can_join_game?: can_join_game?)}
  end

  defp topic(game_id), do: "game:#{game_id}"

  defp subscribe(game_id) do
    Phoenix.PubSub.subscribe(Golf.PubSub, topic(game_id))
  end

  defp broadcast_from(game_id, msg) do
    Phoenix.PubSub.broadcast_from(Golf.PubSub, self(), topic(game_id), msg)
  end

  defp user_is_player?(user_id, players) do
    Enum.any?(players, fn p -> p.user_id == user_id end)
  end
end
