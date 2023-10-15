defmodule Golf.Games.ClientData do
  @derive {Jason.Encoder,
           only: [:id, :status, :turn, :deck, :table_cards, :players, :player_id, :playable_cards]}
  defstruct [:id, :status, :turn, :deck, :table_cards, :players, :player_id, :playable_cards]

  def from(user_id, game, players) do
    positions = hand_positions(map_size(players))
    player_index = Enum.find_index(players, fn {_, p} -> p.user_id == user_id end)

    players =
      players
      |> Map.values()
      |> maybe_rotate(player_index)
      |> Enum.with_index()
      |> Enum.map(fn {player, index} ->
        player
        |> Map.put(:position, Enum.at(positions, index))
        |> Map.put(:score, Golf.Games.score(player.hand))
      end)

    player = player_index && List.first(players)
    playable_cards = Golf.Games.playable_cards(game, player, length(players))

    fields =
      Map.from_struct(game)
      |> Map.put(:players, players)
      |> Map.put(:player_id, player.id)
      |> Map.put(:playable_cards, playable_cards)

    struct(__MODULE__, fields)
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
