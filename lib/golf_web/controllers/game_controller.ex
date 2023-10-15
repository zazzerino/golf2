defmodule GolfWeb.GameController do
  use GolfWeb, :controller
  alias Golf.GamesDb

  def create(conn, _) do
    token = conn.assigns.user_token
    user = Golf.Users.get_user_by_token(token)
    {:ok, game} = GamesDb.create_game(user)

    conn
    |> redirect(to: ~p"/games/#{game.id}")
    |> put_flash(:info, "Game #{game.id} created.")
  end
end
