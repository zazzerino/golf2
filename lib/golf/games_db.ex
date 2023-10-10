defmodule Golf.GamesDb do
  import Ecto.Query

  alias Golf.Repo
  alias Golf.Users.User
  alias Golf.Games
  alias Golf.Games.{Game, Player, JoinRequest}

  def get_game(game_id) do
    Repo.get(Game, game_id)
    |> Repo.preload(players: players_query(game_id))
  end

  defp players_query(game_id) do
    from p in Player,
      where: [game_id: ^game_id],
      order_by: p.turn,
      join: u in User,
      on: [id: p.user_id],
      select: %Player{p | username: u.username}
  end

  def create_game(host_user_id) do
    Games.create_game(host_user_id)
    |> Repo.insert()
  end

  def insert_join_request(%JoinRequest{} = request) do
    Repo.insert(request)
  end

  def get_join_request(request_id) do
    join_request_query(request_id)
    |> Repo.one()
  end

  defp join_request_query(request_id) do
    from jr in JoinRequest,
      where: [id: ^request_id],
      join: u in User,
      on: [id: jr.user_id],
      select: %JoinRequest{jr | username: u.username}
  end

  def get_unconfirmed_join_requests(game_id) do
    unconfirmed_join_requests_query(game_id)
    |> Repo.all()
  end

  defp unconfirmed_join_requests_query(game_id) do
    from jr in JoinRequest,
      where: [game_id: ^game_id, confirmed?: false],
      join: u in User,
      on: [id: jr.user_id],
      order_by: jr.inserted_at,
      select: %JoinRequest{jr | username: u.username}
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

      {:ok, game} = Games.add_player(game, player)
      {:ok, game, player}
    end
  end

  def start_game(game) do
    started_game = Games.start_game(game)
    changes = Map.take(started_game, [:status, :deck, :table_cards, :players])

    game_changeset = Game.changeset(game, changes)

    player_changesets =
      Enum.zip(game.players, changes.players)
      |> Enum.map(fn {old, new} -> Player.changeset(old, %{hand: new.hand}) end)

    {:ok, _} =
      Ecto.Multi.new()
      |> Ecto.Multi.update(:game, game_changeset)
      |> update_player_changesets(player_changesets)
      |> Repo.transaction()

    {:ok, started_game}
  end

  defp update_player_changesets(multi, changesets) do
    Enum.reduce(changesets, multi, fn cs, multi ->
      Ecto.Multi.update(multi, {:player, cs.data.id}, cs)
    end)
  end

  # def game_exists?(game_id) do
  #   from(g in Game, where: [id: ^game_id])
  #   |> Repo.exists?()
  # end
end
