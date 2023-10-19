defmodule GolfWeb.UserLive do
  use GolfWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      send(self(), :load_games)
    end

    {:ok, assign(socket, page_title: "User", games: [])}
  end

  @impl true
  def handle_info(:load_games, socket) do
    user_id = socket.assigns.user.id
    games = Golf.GamesDb.get_user_games(user_id)
    {:noreply, assign(socket, games: games)}
  end

  @impl true
  def handle_event("change_username", %{"username" => name}, socket) when is_binary(name) do
    user = socket.assigns.user
    name = String.trim(name)

    with {:blank, true} <- {:blank, String.length(name) > 0},
         {1, nil} <- Golf.Users.update_username(user.id, name),
         user <- Map.put(user, :username, name) do
      {:noreply, socket |> put_flash(:info, "username updated") |> assign(:user, user)}
    else
      {:blank, _} ->
        {:noreply, put_flash(socket, :error, "Username can't be blank.")}
    end
  end

  @impl true
  def handle_event("game_click", %{"game_id" => game_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/games/#{game_id}")}
  end
end