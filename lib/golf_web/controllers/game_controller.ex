defmodule GolfWeb.GameController do
  use GolfWeb, :controller
  alias Golf.GamesDb

  def create(conn, _) do
    user_id = conn.assigns.user.id
    {:ok, game} = GamesDb.create_game(user_id)

    conn
    |> put_flash(:info, "Game #{game.id} created.")
    |> redirect(to: ~p"/games/#{game.id}")
  end
end
