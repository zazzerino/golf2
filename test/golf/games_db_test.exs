defmodule Golf.GamesDbTest do
  use Golf.DataCase

  alias Golf.{Users, GamesDb}

  test "create game" do
    {:ok, user} = Users.create_user()
    {:ok, game} = GamesDb.create_game(user)

    assert game.status == :init
    assert game.host_id == user.id

    game2 = GamesDb.get_game(game.id)
    assert game == game2

    {:ok, game3} = GamesDb.start_game(game) |> dbg()
    assert game3.status == :flip_2
    assert game3.players |> List.first() |> Map.get(:hand) |> length() == 6

    game4 = GamesDb.get_game(game3.id) |> dbg()
  end
end
