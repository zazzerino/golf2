defmodule GolfWeb.HomeLive do
  use GolfWeb, :live_view
  alias Golf.GamesDb

  @inserted_at_format "%y/%m/%d %H:%m:%S"

  @impl true
  def mount(_, _, socket) do
    if connected?(socket) do
      send(self(), :load_games)
      :ok = Phoenix.PubSub.subscribe(Golf.PubSub, "games")
    end

    {:ok,
     assign(socket,
       page_title: "Home",
       csrf_token: Phoenix.Controller.get_csrf_token(),
       games: []
     )}
  end

  @impl true
  def handle_info(:load_games, socket) do
    games =
      GamesDb.get_home_games()
      |> Enum.map(fn game ->
        Map.update!(game, :inserted_at, &Calendar.strftime(&1, @inserted_at_format))
      end)

    {:noreply, assign(socket, :games, games)}
  end

  @impl true
  def handle_info({:game_created, game}, socket) do
    {:noreply, assign(socket, :games, [game | socket.assigns.games])}
  end

  @impl true
  def handle_event("create_game", _, socket) do
    user = socket.assigns.user
    {:ok, game} = Golf.GamesDb.create_game(user)
    :ok = Phoenix.PubSub.broadcast(Golf.PubSub, "games", {:game_created, game})
    {:noreply, redirect(socket, to: ~p"/games/#{game.id}")}
  end

  @impl true
  def handle_event("game_click", %{"game_id" => game_id}, socket) do
    {:noreply, redirect(socket, to: ~p"/games/#{game_id}")}
  end

  @impl true
  def handle_event("change_username", %{"username" => name}, socket) when is_binary(name) do
    with name <- String.trim(name),
         true <- String.length(name) > 0,
         user <- socket.assigns.user,
         {1, nil} <- Golf.Users.update_username(user.id, name),
         user <- Map.put(user, :username, name) do
      {:noreply, socket |> put_flash(:info, "username updated") |> assign(:user, user)}
    else
      err ->
        {:noreply, put_flash(socket, :error, "#{err}")}
    end
  end
end
