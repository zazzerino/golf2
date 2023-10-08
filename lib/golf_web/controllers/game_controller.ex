defmodule GolfWeb.GameController do
  use GolfWeb, :controller
  alias Golf.Games

  def create(conn, _) do
    user_id = conn.assigns.user.id
    {:ok, %{game: game}} = Games.create_game(user_id)

    conn
    |> put_flash(:info, "Game #{game.id} created.")
    |> redirect(to: ~p"/games/#{game.id}")
  end
end
