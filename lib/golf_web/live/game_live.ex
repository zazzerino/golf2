defmodule GolfWeb.GameLive do
  use GolfWeb, :live_view

  alias GolfWeb.UserAuth
  alias Golf.GamesDb
  alias Golf.Games
  alias Golf.Games.{Game, GameEvent, JoinRequest}

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
         players: nil,
         player_id: nil,
         playable_cards: nil,
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

  defp player_data(user_id, game, players) do
    positions = hand_positions(map_size(players))

    players =
      players
      |> Enum.with_index()
      |> Enum.map(fn {{id, player}, index} ->
        pos = Enum.at(positions, index)
        {id, put_position_and_score(player, pos)}
      end)
      |> Enum.into(%{})

    player =
      players
      |> Map.values()
      |> Enum.find(fn p -> p.user_id == user_id end)

    player_id = player && player.id
    playable_cards = Games.playable_cards(game, player)

    %{players: players, player_id: player_id, playable_cards: playable_cards}
  end

  @impl true
  def handle_info({:load_game, game_id}, socket) do
    with user_id <- socket.assigns.user.id,
         game when is_struct(game) <- GamesDb.get_game(game_id),
         players when is_map(players) <- GamesDb.get_players(game_id),
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
          not Enum.any?(players, fn {_, p} -> p.user_id == user_id end)

      %{players: players, player_id: player_id, playable_cards: playable_cards} =
        player_data =
        player_data(user_id, game, players)

      {:noreply,
       socket
       |> push_event("game_loaded", %{"game" => Map.merge(game, player_data)})
       |> assign(
         game: game,
         players: players,
         player_id: player_id,
         playable_cards: playable_cards,
         user_is_host?: user_is_host?,
         can_start_game?: can_start_game?,
         can_join_game?: can_join_game?,
         join_requests: join_requests
       )}
    end
  end

  @impl true
  def handle_info({:game_started, game, players}, socket) do
    user_id = socket.assigns.user.id

    %{players: players, player_id: player_id, playable_cards: playable_cards} =
      player_data =
      player_data(user_id, game, players)

    {:noreply,
     socket
     |> push_event("game_started", %{"game" => Map.merge(game, player_data)})
     |> assign(
       game: game,
       players: players,
       player_id: player_id,
       playable_cards: playable_cards,
       can_start_game?: false,
       can_join_game?: false
     )}
  end

  @impl true
  def handle_info({:requested_join, request}, socket) do
    user_made_request? = request.user_id == socket.assigns.user.id
    can_join_game? = if user_made_request?, do: false, else: socket.assigns.can_join_game?
    requests = GamesDb.get_unconfirmed_join_requests(socket.assigns.game.id)

    {:noreply, assign(socket, join_requests: requests, can_join_game?: can_join_game?)}
  end

  @impl true
  def handle_info({:player_joined, game, player_id}, socket) do
    join_requests = GamesDb.get_unconfirmed_join_requests(game.id)

    {:noreply,
     socket
     |> push_event("player_joined", %{"game" => game, "player_id" => player_id})
     |> assign(game: game, join_requests: join_requests)}
  end

  @impl true
  def handle_info({:game_event, game, event}, socket) do
    IO.inspect(event, label: "GAME EVENT RECV")

    {:noreply,
     socket
     |> push_event("game_event", %{"game" => game, "event" => event})
     |> assign(game: game)}
  end

  @impl true
  def handle_event("start_game", _value, socket) do
    user_id = socket.assigns.user.id
    game = socket.assigns.game

    if user_id == game.host_id do
      players = socket.assigns.players
      {:ok, game, players} = GamesDb.start_game(game, players)
      broadcast(game.id, {:game_started, game, players})
      {:noreply, assign(socket, game: game, players: players, can_start_game?: false)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("request_join", _value, socket) do
    game_id = socket.assigns.game.id
    request = JoinRequest.new(game_id, socket.assigns.user)
    {:ok, request} = GamesDb.insert_join_request(request)

    broadcast(game_id, {:requested_join, request})
    {:noreply, socket}
  end

  @impl true
  def handle_event("confirm_join", %{"request_id" => req_id}, socket) do
    # with true <- socket.assigns.user_is_host?,
    #      {req_id, _} when is_integer(req_id) <- Integer.parse(req_id),
    #      req when is_struct(req) <- GamesDb.get_join_request(req_id),
    #      {:ok, game, player} <- GamesDb.confirm_join_request(socket.assigns.game, req) do
    #   user_id = socket.assigns.user.id
    #   game = game |> put_user_data(user_id)
    #   broadcast(game.id, {:player_joined, game, player.id})
    # end

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "hand_click",
        %{"player_id" => player_id, "hand_index" => hand_index},
        socket
      ) do
    # user_id = socket.assigns.user.id
    # game = socket.assigns.game

    # with {player, _} = Games.get_player(game, player_id),
    #      true <- player.user_id == user_id,
    #      card <- String.to_existing_atom("hand_#{hand_index}"),
    #      true <- Enum.member?(game.playable_cards, card),
    #      event <- GameEvent.new(game.id, player.id, :flip, hand_index),
    #      {:ok, game, event} <- GamesDb.handle_event(game, event) do
    #   game = put_user_data(game, user_id)
    #   broadcast(game.id, {:game_event, game, event})
    #   {:noreply, assign(socket, game: game)}
    # end

    {:noreply, socket}
  end

  defp topic(game_id), do: "game:#{game_id}"

  defp subscribe(topic) do
    Phoenix.PubSub.subscribe(Golf.PubSub, topic)
  end

  defp broadcast(game_id, msg) do
    Phoenix.PubSub.broadcast(Golf.PubSub, topic(game_id), msg)
  end

  # defp user_is_playing?(user_id, players) do
  #   Enum.any?(players, fn {_, p} -> p.user_id == user_id end)
  # end

  # defp user_is_player?(user_id, players) do
  #   Enum.any?(players, fn p -> p.user_id == user_id end)
  # end

  # defp put_user_data(game, user_id) do
  #   positions = hand_positions(length(game.players))

  #   player_index =
  #     Enum.find_index(game.players, fn player ->
  #       player.user_id == user_id
  #     end)

  #   player = player_index && Enum.at(game.players, player_index)
  #   playable_cards = Games.playable_cards(game, player)

  #   players =
  #     game.players
  #     |> maybe_rotate(player_index)
  #     |> put_positions_and_scores(positions)

  #   %Game{game | players: players, playable_cards: playable_cards}
  # end

  defp hand_positions(num_players) do
    case num_players do
      1 -> ~w(bottom)
      2 -> ~w(bottom top)
      3 -> ~w(bottom left right)
      4 -> ~w(bottom left top right)
    end
  end

  defp put_position_and_score(player, position) do
    player
    |> Map.put(:position, position)
    |> Map.put(:score, Games.score(player.hand))
  end

  # don't do anything if n is 0 or nil
  defp maybe_rotate(list, 0), do: list
  defp maybe_rotate(list, nil), do: list

  # otherwise rotate the list n elements
  defp maybe_rotate(list, n) do
    list
    |> Stream.cycle()
    |> Stream.drop(n)
    |> Stream.take(length(list))
    |> Enum.to_list()
  end
end
