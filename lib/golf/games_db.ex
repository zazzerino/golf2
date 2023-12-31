defmodule Golf.GamesDb do
  import Ecto.Query

  require Golf.Games

  alias Golf.Repo
  alias Golf.Users.User
  alias Golf.Games
  alias Golf.Games.{Game, Player, GameEvent, JoinRequest, Tourney, ChatMsg}

  def get_game(game_id) do
    Repo.get(Game, game_id)
    |> Repo.preload(players: players_query(game_id))
  end

  defp players_query(game_id) do
    from p in Player,
      where: [game_id: ^game_id],
      join: u in User,
      on: [id: p.user_id],
      order_by: p.turn,
      select: %Player{p | username: u.username}
  end

  def get_home_games() do
    from(g in Game,
      where: [status: :init],
      order_by: [desc: :inserted_at],
      join: u in User,
      on: [id: g.host_id],
      select: %Game{g | host_username: u.username}
    )
    |> Repo.all()
  end

  def get_tourney(tourney_id) do
    Repo.get(Tourney, tourney_id)
    |> Repo.preload(:games)
  end

  def get_user_games(user_id) do
    from(u in User,
      where: [id: ^user_id],
      join: p in Player,
      on: [user_id: u.id],
      join: g in Game,
      on: [id: p.game_id],
      join: host in User,
      on: [id: g.host_id],
      order_by: [desc: g.inserted_at],
      select: %{
        id: g.id,
        inserted_at: g.inserted_at,
        status: g.status,
        host_id: host.id,
        host_username: host.username
      }
    )
    |> Repo.all()
  end

  def get_chat_messages(game_id) do
    from(cm in ChatMsg, where: [game_id: ^game_id])
    |> Repo.all()
  end

  def insert_chat_message(%ChatMsg{} = chat_msg) do
    chat_msg
    |> ChatMsg.changeset()
    |> Repo.insert()
  end

  @default_tourney_opts [num_rounds: 4]

  def create_tourney(%User{} = host, opts \\ []) do
    opts = Keyword.merge(@default_tourney_opts, opts)

    Games.create_tourney(host, opts[:num_rounds])
    |> Tourney.changeset()
    |> Repo.insert()
  end

  def create_game(%User{} = host) do
    Games.create_game(host)
    |> Game.changeset()
    |> Repo.insert()
  end

  def start_game(%Game{status: :init} = game) do
    {:ok, new_game} = Games.start_game(game)
    game_changeset = Game.changeset(game, Map.take(new_game, [:status, :deck, :table_cards]))

    player_changesets =
      game.players
      |> Enum.with_index()
      |> Enum.map(fn {player, index} ->
        new_player = Enum.at(new_game.players, index)
        Player.changeset(player, Map.take(new_player, [:hand]))
      end)

    {:ok, _} =
      Ecto.Multi.new()
      |> Ecto.Multi.update(:game, game_changeset)
      |> update_player_changesets(player_changesets)
      |> Repo.transaction()

    {:ok, new_game}
  end

  defp update_player_changesets(multi, changesets) do
    Enum.reduce(changesets, multi, fn cs, multi ->
      Ecto.Multi.update(multi, {:player, cs.data.id}, cs)
    end)
  end

  def handle_event(%Game{} = game, %GameEvent{} = event) do
    with {player, index} <- Games.get_player(game.players, event.player_id),
         true <- Games.is_players_turn(game, player),
         {:ok, new_game} = Games.handle_event(game, event, {player, index}) do
      game_changeset =
        Game.changeset(
          game,
          Map.take(new_game, [:status, :turn, :deck, :table_cards])
        )

      {player, index} = Games.get_player(game.players, event.player_id)
      new_player = Enum.at(new_game.players, index)

      player_changeset =
        Player.changeset(
          player,
          Map.take(new_player, [:hand, :held_card])
        )

      {:ok, %{event: event}} =
        Ecto.Multi.new()
        |> Ecto.Multi.update(:game, game_changeset)
        |> Ecto.Multi.update(:player, player_changeset)
        |> Ecto.Multi.insert(:event, event)
        |> Repo.transaction()

      {:ok, new_game, event}
    end
  end

  def insert_join_request(%JoinRequest{} = request) do
    Repo.insert(request)
  end

  def get_join_request(request_id) do
    join_request_query(request_id)
    |> Repo.one()
  end

  def get_unconfirmed_join_requests(game_id) do
    unconfirmed_join_requests_query(game_id)
    |> Repo.all()
  end

  def confirm_join_request(%Game{} = game, %JoinRequest{} = request) do
    if Enum.any?(game.players, fn p -> p.user_id == request.user_id end) do
      {:error, :already_playing}
    else
      player = %Player{
        game_id: game.id,
        user_id: request.user_id,
        username: request.username,
        turn: length(game.players)
      }

      request_changeset = JoinRequest.changeset(request, %{confirmed?: true})

      {:ok, %{player: player}} =
        Ecto.Multi.new()
        |> Ecto.Multi.insert(:player, player)
        |> Ecto.Multi.update(:join_request, request_changeset)
        |> Repo.transaction()

      game = Map.put(game, :players, game.players ++ [player])
      {:ok, game, request.user_id}
    end
  end

  defp join_request_query(request_id) do
    from jr in JoinRequest,
      where: [id: ^request_id],
      join: u in User,
      on: [id: jr.user_id],
      select: %JoinRequest{jr | username: u.username}
  end

  defp unconfirmed_join_requests_query(game_id) do
    from jr in JoinRequest,
      where: [game_id: ^game_id, confirmed?: false],
      join: u in User,
      on: [id: jr.user_id],
      order_by: jr.inserted_at,
      select: %JoinRequest{jr | username: u.username}
  end
end
