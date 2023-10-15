defmodule Golf.GamesDb do
  import Ecto.Query

  alias Golf.Repo
  alias Golf.Users.User
  alias Golf.Games
  alias Golf.Games.{Game, Player, GameEvent, JoinRequest}

  def get_game(game_id) do
    Repo.get(Game, game_id)
  end

  def get_players(game_id) do
    players_query(game_id)
    |> Repo.all()
    |> Enum.into(%{})
  end

  def create_game(%User{} = host) do
    game = Game.new(host.id)
    player = Player.new(host, 0)

    {:ok, %{game: game, player: player}} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:game, Game.changeset(game))
      |> Ecto.Multi.insert(:player, fn %{game: game} ->
        player
        |> Map.put(:game_id, game.id)
        |> Player.changeset()
      end)
      |> Repo.transaction()

    players = %{player.id => player}
    {:ok, game, players}
  end

  def start_game(%Game{} = game, players) do
    {:ok, new_game, new_players} = Games.start_game(game, players)
    game_changeset = Game.changeset(game, Map.take(new_game, [:status, :deck, :table_cards]))

    player_changesets =
      players
      |> Enum.map(fn {id, player} ->
        new_player = Map.get(new_players, id)
        Player.changeset(player, Map.take(new_player, [:hand]))
      end)

    {:ok, %{game: game} = updates} =
      Ecto.Multi.new()
      |> Ecto.Multi.update(:game, game_changeset)
      |> update_player_changesets(player_changesets)
      |> Repo.transaction()

    players = reduce_player_updates(updates)
    {:ok, game, players}
  end

  defp update_player_changesets(multi, changesets) do
    Enum.reduce(changesets, multi, fn cs, multi ->
      Ecto.Multi.update(multi, {:player, cs.data.id}, cs)
    end)
  end

  # takes the updates from an Ecto.Multi and returns a
  # map %{id => player} of the players who were updated
  defp reduce_player_updates(updates) do
    Enum.reduce(updates, %{}, fn {key, val}, acc ->
      case key do
        {:player, id} ->
          Map.put(acc, id, val)

        _ ->
          acc
      end
    end)
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

  # def confirm_join_request(%Game{} = game, %JoinRequest{} = request) do
  #   if Enum.any?(game.players, fn p -> p.user_id == request.user_id end) do
  #     {:error, :already_playing}
  #   else
  #     player = %Player{
  #       game_id: game.id,
  #       user_id: request.user_id,
  #       username: request.username,
  #       turn: length(game.players)
  #     }

  #     request_changeset = JoinRequest.changeset(request, %{confirmed?: true})

  #     {:ok, %{player: player}} =
  #       Ecto.Multi.new()
  #       |> Ecto.Multi.insert(:player, player)
  #       |> Ecto.Multi.update(:join_request, request_changeset)
  #       |> Repo.transaction()

  #     # {:ok, game} = Games.add_player(game, player)
  #     {:ok, game, player}
  #   end
  # end

  defp players_query(game_id) do
    from p in Player,
      where: [game_id: ^game_id],
      join: u in User,
      on: [id: p.user_id],
      select: {p.id, %Player{p | username: u.username}}
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

  def handle_event(%Game{} = game, players, %GameEvent{} = event) do
    {:ok, new_game, new_players} = Games.handle_event(game, players, event)

    game_changes = Map.take(new_game, [:status, :deck])
    game_changeset = Game.changeset(game, game_changes)

    player = Map.get(players, event.player_id)
    new_player = Map.get(new_players, event.player_id)

    player_changes = Map.take(new_player, [:hand])
    player_changeset = Player.changeset(player, player_changes)

    {:ok, %{event: event}} =
      Ecto.Multi.new()
      |> Ecto.Multi.update(:game, game_changeset)
      |> Ecto.Multi.update(:player, player_changeset)
      |> Ecto.Multi.insert(:event, event)
      |> Repo.transaction()

    {:ok, new_game, new_players, event}
  end

  # def game_exists?(game_id) do
  #   from(g in Game, where: [id: ^game_id])
  #   |> Repo.exists?()
  # end
end
