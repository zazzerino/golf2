defmodule Golf.Games do
  alias Golf.Games.{Game, Player}

  @card_names for rank <- ~w(A 2 3 4 5 6 7 8 9 T J Q K),
                  suit <- ~w(C D H S),
                  do: rank <> suit

  @num_decks 2
  @hand_size 6

  defguard is_players_turn(game, player)
           when rem(game.turn, length(game.players)) == player.turn

  def create_game(host_user_id) do
    deck = new_deck(@num_decks) |> Enum.shuffle()
    host_player = %Player{user_id: host_user_id, turn: 0}
    %Game{host_id: host_user_id, deck: deck, players: [host_player]}
  end

  def add_player(%Game{status: :init} = game, %Player{} = player) do
    {:ok, %Game{game | players: game.players ++ [player]}}
  end

  def start_game(%Game{status: :init} = game) do
    # deal hands to players
    num_cards_to_deal = @hand_size * length(game.players)
    {:ok, cards_to_deal, deck} = deal_from_deck(game.deck, num_cards_to_deal)

    hands =
      cards_to_deal
      |> Enum.map(fn name -> %{"name" => name, "face_up?" => false} end)
      |> Enum.chunk_every(@hand_size)

    players =
      Enum.zip(game.players, hands)
      |> Enum.map(fn {player, hand} -> %Player{player | hand: hand} end)

    # deal table card
    {:ok, card, deck} = deal_from_deck(deck)
    table_cards = [card | game.table_cards]

    %Game{game | status: :flip_2, deck: deck, table_cards: table_cards, players: players}
  end

  def score(hand) do
    hand
    |> Enum.map(&rank_or_nil/1)
    |> score_ranks(0)
  end

  def playable_cards(%Game{status: :flip2}, %Player{} = player) do
    if num_cards_face_up(player.hand) < 2 do
      face_down_cards(player.hand)
    else
      []
    end
  end

  def playable_cards(%Game{} = game, %Player{} = player) when is_players_turn(game, player) do
    case game.status do
      s when s in [:flip_2, :flip] ->
        face_down_cards(player.hand)

      s when s in [:take, :last_take] ->
        [:deck, :table]

      s when s in [:hold, :last_hold] ->
        [:held, :hand_0, :hand_1, :hand_2, :hand_3, :hand_4, :hand_5]

      _ ->
        []
    end
  end

  def playable_cards(%Game{}, %Player{}), do: []

  defp new_deck(1), do: @card_names

  defp new_deck(num_decks) when num_decks > 1 do
    @card_names ++ new_deck(num_decks - 1)
  end

  defp deal_from_deck([], _) do
    {:error, :empty_deck}
  end

  defp deal_from_deck(deck, n) when length(deck) < n do
    {:error, :not_enough_cards}
  end

  defp deal_from_deck(deck, n) do
    {dealt_cards, deck} = Enum.split(deck, n)
    {:ok, dealt_cards, deck}
  end

  defp deal_from_deck(deck) do
    with {:ok, [card], deck} <- deal_from_deck(deck, 1) do
      {:ok, card, deck}
    end
  end

  defp num_cards_face_up(hand) do
    Enum.count(hand, fn card -> card["face_up?"] end)
  end

  defp face_down_cards(hand) do
    hand
    |> Enum.with_index()
    |> Enum.reject(fn {card, _} -> card["face_up?"] end)
    |> Enum.map(fn {_, index} -> String.to_existing_atom("hand_#{index}") end)
  end

  defp rank_value(rank) when is_integer(rank) do
    case rank do
      ?K -> 0
      ?A -> 1
      ?2 -> 2
      ?3 -> 3
      ?4 -> 4
      ?5 -> 5
      ?6 -> 6
      ?7 -> 7
      ?8 -> 8
      ?9 -> 9
      r when r in [?T, ?J, ?Q] -> 10
    end
  end

  defp rank_value(<<rank, _>>), do: rank_value(rank)

  defp rank_or_nil(%{"face_up?" => true, "name" => <<rank, _>>}), do: rank
  defp rank_or_nil(_), do: nil

  defp score_ranks(ranks, total) do
    case ranks do
      # all match
      [a, a, a, a, a, a] when not is_nil(a) ->
        -40

      # outer cols match
      [a, b, a, a, c, a] when not is_nil(a) ->
        score_ranks([b, c], total - 20)

      # left 2 cols match
      [a, a, b, a, a, c] when not is_nil(a) ->
        score_ranks([b, c], total - 10)

      # right 2 cols match
      [a, b, b, c, b, b] when not is_nil(b) ->
        score_ranks([a, c], total - 10)

      # left col match
      [a, b, c, a, d, e] when not is_nil(a) ->
        score_ranks([b, c, d, e], total)

      # middle col match
      [a, b, c, d, b, e] when not is_nil(b) ->
        score_ranks([a, c, d, e], total)

      # right col match
      [a, b, c, d, e, c] when not is_nil(c) ->
        score_ranks([a, b, d, e], total)

      # left col match, 2nd pass
      [a, b, a, c] when not is_nil(a) ->
        score_ranks([b, c], total)

      # right col match, 2nd pass
      [a, b, c, b] when not is_nil(b) ->
        score_ranks([a, c], total)

      [a, a] when not is_nil(a) ->
        total

      _ ->
        ranks
        |> Enum.reject(&is_nil/1)
        |> Enum.reduce(0, fn name, acc -> rank_value(name) + acc end)
        |> Kernel.+(total)
    end
  end
end
