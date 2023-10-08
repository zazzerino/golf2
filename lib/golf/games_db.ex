defmodule Golf.GamesDb do
  import Ecto.Query

  alias Golf.Repo
  alias Golf.Games
  alias Golf.Games.{Game, Player}

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
    Enum.reduce(changesets, multi, &update_player_changeset/2)
  end

  defp update_player_changeset(cs, multi) do
    Ecto.Multi.update(multi, {:player, cs.data.id}, cs)
  end

  # def game_exists?(game_id) do
  #   from(g in Game, where: [id: ^game_id])
  #   |> Repo.exists?()
  # end
end
