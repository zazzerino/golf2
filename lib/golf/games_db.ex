defmodule Golf.GamesDb do
  import Ecto.Query

  alias Golf.Repo
  alias Golf.Games
  alias Golf.Games.{Game, Player}

  def get_game(game_id) do
    Repo.get(Game, game_id)
    |> Repo.preload(players: players_query(game_id))
  end

  def create_game(host_user_id) do
    Games.create_game(host_user_id)
    |> Repo.insert()
  end

  defp players_query(game_id) do
    from p in Player,
      where: [game_id: ^game_id],
      order_by: p.turn,
      join: u in Golf.Users.User,
      on: [id: p.user_id],
      select: %Player{p | username: u.username}
  end

  # def game_exists?(game_id) do
  #   from(g in Game, where: [id: ^game_id])
  #   |> Repo.exists?()
  # end
end
