defmodule Golf.GamesTest do
  use ExUnit.Case

  alias Golf.Users.User
  alias Golf.Games

  test "create game" do
    user = %User{id: 1, username: "alice"}
    game = Games.create_game(user)

    assert game.host_id == user.id
    assert length(game.players) == 1
    assert game.status == :init

    {:ok, game2} = Games.start_game(game)
    assert game2.status == :flip_2

    # Enum.map(game2.players, fn p ->
    #   Games.playable_cards(game2, p) |> dbg()
    # end)
  end
end
