defmodule Golf.Games.GameData do
  @derive {Jason.Encoder,
           only: [
             :id,
             :status,
             :turn,
             :deck,
             :table_cards,
             :players,
             :player_id,
             :playable_cards,
             :current_player_id
           ]}
  defstruct [
    :id,
    :status,
    :turn,
    :deck,
    :table_cards,
    :players,
    :player_id,
    :playable_cards,
    :current_player_id
  ]

  def from(user_id, game) do
    num_players = length(game.players)
    positions = hand_positions(num_players)
    player_index = Enum.find_index(game.players, fn p -> p.user_id == user_id end)

    players =
      game.players
      |> maybe_rotate(player_index)
      |> put_player_data(positions)

    player = player_index && List.first(players)
    playable_cards = Golf.Games.playable_cards(game, player)
    current_player = Golf.Games.current_player(game, num_players)

    fields =
      Map.from_struct(game)
      |> Map.put(:players, players)
      |> Map.put(:player_id, player && player.id)
      |> Map.put(:playable_cards, playable_cards)
      |> Map.put(:current_player_id, current_player && current_player.id)

    struct(__MODULE__, fields)
  end

  defp put_player_data(players, positions) do
    players
    |> Enum.with_index()
    |> Enum.map(fn {player, index} ->
      player
      |> Map.put(:position, Enum.at(positions, index))
      |> Map.put(:score, Golf.Games.score(player.hand))
    end)
  end

  defp hand_positions(num_players) do
    case num_players do
      1 -> ~w(bottom)
      2 -> ~w(bottom top)
      3 -> ~w(bottom left right)
      4 -> ~w(bottom left top right)
    end
  end

  # don't do anything if n is 0 or nil
  defp maybe_rotate(list, 0), do: list
  defp maybe_rotate(list, nil), do: list

  # otherwise rotate the list n elements
  defp maybe_rotate(list, n) do
    list
    |> Stream.cycle()
    |> Stream.drop(n)
    |> Stream.take(length(list))
    |> Enum.to_list()
  end
end
