defmodule GolfWeb.HomeLive do
  use GolfWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      send(self(), :load_games)
      :ok = Phoenix.PubSub.subscribe(Golf.PubSub, "games")
    end

    {:ok,
     assign(socket,
       page_title: "Home",
       games: []
     )}
  end

  @impl true
  def handle_info(:load_games, socket) do
    games =
      Golf.GamesDb.get_home_games()
      |> Enum.map(fn game ->
        Map.update!(game, :inserted_at, &Calendar.strftime(&1, Golf.inserted_at_format()))
      end)

    {:noreply, assign(socket, :games, games)}
  end

  @impl true
  def handle_info({:game_created, game}, socket) do
    {:noreply, assign(socket, :games, [game | socket.assigns.games])}
  end

  @impl true
  def handle_event("create_game", _value, socket) do
    user = socket.assigns.user
    {:ok, game} = Golf.GamesDb.create_game(user)
    :ok = Phoenix.PubSub.broadcast(Golf.PubSub, "games", {:game_created, game})
    {:noreply, push_navigate(socket, to: ~p"/games/#{game.id}")}
  end

  @impl true
  def handle_event("create_tourney", _value, socket) do
    # user = socket.assigns.user
    # {:ok, tourney} = Golf.GamesDb.create_tourney(user)
    # {:noreply, push_navigate(socket, to: ~p"/tourneys/#{tourney.id}")}
    # {:noreply, push_navigate(socket, to: ~p"/tourneys/opts")}
    {:noreply, push_navigate(socket, to: ~p"/tourneys/opts")}
  end

  @impl true
  def handle_event("game_click", %{"game_id" => game_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/games/#{game_id}")}
  end
end
