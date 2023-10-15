defmodule GolfWeb.GameLive do
  use GolfWeb, :live_view

  alias GolfWeb.UserAuth
  alias Golf.GamesDb
  alias Golf.Games
  alias Golf.Games.{GameData, GameEvent, JoinRequest}

  @impl true
  def mount(%{"game_id" => game_id}, session, socket) do
    with token when is_binary(token) <- session["user_token"],
         {:ok, _, user_id} <- UserAuth.verify(token),
         user when is_struct(user) <- Golf.Users.get_user(user_id),
         {game_id, _} <- Integer.parse(game_id) do
      if connected?(socket) do
        send(self(), {:load_game, game_id})
      end

      {:ok,
       socket
       |> assign(
         user: user,
         page_title: "Game #{game_id}",
         game_id: game_id,
         game: nil,
         player_id: nil,
         user_is_host?: nil,
         can_start_game?: nil,
         can_join_game?: nil,
         join_requests: nil
       )}
    else
      err ->
        {:ok, socket |> redirect(to: ~p"/") |> put_flash(:error, "#{err}")}
    end
  end

  @impl true
  def handle_info({:load_game, game_id}, socket) do
    with user_id when is_integer(user_id) <- socket.assigns.user.id,
         game when is_struct(game) <- GamesDb.get_game(game_id),
         :ok <- subscribe(topic(game_id)) do
      game_is_init? = game.status == :init
      user_is_host? = game.host_id == user_id
      can_start_game? = game_is_init? and user_is_host?

      join_requests =
        if game_is_init? do
          GamesDb.get_unconfirmed_join_requests(game_id)
        end

      has_requested_join? =
        join_requests && Enum.any?(join_requests, fn req -> req.user_id == user_id end)

      can_join_game? =
        game_is_init? and
          not has_requested_join? and
          not Enum.any?(game.players, fn p -> p.user_id == user_id end)

      %{player_id: player_id} = game_data = GameData.from(user_id, game)

      {:noreply,
       socket
       |> push_event("game_loaded", %{"game" => game_data})
       |> assign(
         game: game,
         player_id: player_id,
         user_is_host?: user_is_host?,
         can_start_game?: can_start_game?,
         can_join_game?: can_join_game?,
         join_requests: join_requests
       )}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Game #{game_id} not found.")}
    end
  end

  @impl true
  def handle_info({:game_started, game}, socket) do
    user_id = socket.assigns.user.id
    game_data = GameData.from(user_id, game)

    {:noreply,
     socket
     |> push_event("game_started", %{"game" => game_data})
     |> assign(
       game: game,
       can_start_game?: false,
       can_join_game?: false
     )}
  end

  @impl true
  def handle_info({:join_requested, request}, socket) do
    user_id = socket.assigns.user.id
    game_id = socket.assigns.game_id
    requests = GamesDb.get_unconfirmed_join_requests(game_id)

    can_join_game? =
      if request.user_id == user_id do
        false
      else
        socket.assigns.can_join_game?
      end

    {:noreply, assign(socket, join_requests: requests, can_join_game?: can_join_game?)}
  end

  @impl true
  def handle_info({:player_joined, game, joined_user_id}, socket) do
    user_id = socket.assigns.user.id
    game_data = GameData.from(user_id, game)

    player_id =
      if user_id = joined_user_id do
        player = Enum.find(game_data.players, fn p -> p.user_id == user_id end)
        player && player.id
      end

    join_requests = GamesDb.get_unconfirmed_join_requests(game.id)

    {:noreply,
     socket
     |> push_event("player_joined", %{"game" => game_data, "user_id" => joined_user_id})
     |> assign(game: game, player_id: player_id, join_requests: join_requests)}
  end

  @impl true
  def handle_info({:game_event, game, event}, socket) do
    user_id = socket.assigns.user.id
    %{playable_cards: playable_cards} = game_data = GameData.from(user_id, game)

    {:noreply,
     socket
     |> push_event("game_event", %{"game" => game_data, "event" => event})
     |> assign(game: game, playable_cards: playable_cards)}
  end

  @impl true
  def handle_event("start_game", _value, socket) when socket.assigns.user_is_host? do
    game = socket.assigns.game
    {:ok, game} = GamesDb.start_game(game)
    broadcast(game.id, {:game_started, game})
    {:noreply, assign(socket, can_start_game?: false)}
  end

  @impl true
  def handle_event("request_join", _value, socket) do
    user = socket.assigns.user
    game_id = socket.assigns.game.id
    request = JoinRequest.new(game_id, user)
    {:ok, request} = GamesDb.insert_join_request(request)

    broadcast(game_id, {:join_requested, request})
    {:noreply, socket}
  end

  @impl true
  def handle_event("confirm_join", %{"request_id" => req_id}, socket)
      when socket.assigns.user_is_host? do
    with game when is_struct(game) <- socket.assigns.game,
         {req_id, _} when is_integer(req_id) <- Integer.parse(req_id),
         req when is_struct(req) <- GamesDb.get_join_request(req_id),
         {:ok, game, user_id} <- GamesDb.confirm_join_request(game, req) do
      broadcast(game.id, {:player_joined, game, user_id})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "hand_click",
        %{"player_id" => player_id, "hand_index" => hand_index},
        socket
      ) do
    user_id = socket.assigns.user.id
    game = socket.assigns.game

    with {player, _} when is_struct(player) <- Games.get_player(game.players, player_id),
         true <- player.user_id == user_id,
         card <- String.to_existing_atom("hand_#{hand_index}"),
         playable_cards = Games.playable_cards(game, player),
         true <- Enum.member?(playable_cards, card),
         event <- GameEvent.new(game.id, player.id, :flip, hand_index),
         {:ok, game, event} <- GamesDb.handle_event(game, event) do
      broadcast(game.id, {:game_event, game, event})
      {:noreply, assign(socket, game: game)}
    else
      _ ->
        {:noreply, socket}
    end
  end

  defp topic(game_id), do: "game:#{game_id}"

  defp subscribe(topic) do
    Phoenix.PubSub.subscribe(Golf.PubSub, topic)
  end

  defp broadcast(game_id, msg) do
    Phoenix.PubSub.broadcast(Golf.PubSub, topic(game_id), msg)
  end
end
