defmodule Golf.GamesDb do
  import Ecto.Query

  alias Golf.Repo
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
      join: u in Golf.Users.User,
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

  def confirm_join_request(%Game{} = game, %JoinRequest{} = request) do
    next_turn = length(game.players)
    new_player = %Player{game_id: game.id, user_id: request.user_id, turn: next_turn}
    request_changeset = JoinRequest.changeset(request, %{confirmed?: true})

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:player, new_player)
    |> Ecto.Multi.update(:join_request, request_changeset)
    |> Repo.transaction()
  end

  def start_game(game) do
    started_game = Games.start_game(game)
    changes = Map.take(started_game, [:status, :deck, :table_cards, :players])

    game_changeset = Game.changeset(game, changes)

    player_changesets =
      game.players
      |> Enum.zip(changes.players)
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
