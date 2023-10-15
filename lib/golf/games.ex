defmodule Golf.Games do
  alias Golf.Games.{Game, Player, GameEvent}

  @card_names for rank <- ~w(A 2 3 4 5 6 7 8 9 T J Q K),
                  suit <- ~w(C D H S),
                  do: rank <> suit

  @num_decks 2
  @hand_size 6

  defguard is_players_turn(game, player, num_players)
           when rem(game.turn, num_players) == player.turn

  def start_game(%Game{status: :init} = game, players) do
    # deal hands to players
    num_cards_to_deal = @hand_size * map_size(players)
    {:ok, card_names, deck} = deal_from_deck(game.deck, num_cards_to_deal)

    hands =
      card_names
      |> Enum.map(fn name -> %{"name" => name, "face_up?" => false} end)
      |> Enum.chunk_every(@hand_size)

    players =
      Enum.with_index(players)
      |> Enum.map(fn {{id, player}, index} ->
        hand = Enum.at(hands, index)
        {id, Map.put(player, :hand, hand)}
      end)
      |> Enum.into(%{})

    # deal table card
    {:ok, card, deck} = deal_from_deck(deck)
    table_cards = [card | game.table_cards]

    game = %Game{game | status: :flip_2, deck: deck, table_cards: table_cards}
    {:ok, game, players}
  end

  def handle_event(%Game{status: :flip_2} = game, players, %GameEvent{action: :flip} = event) do
    player = Map.get(players, event.player_id)

    if num_cards_face_up(player.hand) < 2 do
      hand = flip_card(player.hand, event.hand_index)
      players = Map.update!(players, player.id, &Map.put(&1, :hand, hand))

      all_done_flipping? =
        Enum.all?(players, fn {_, p} ->
          num_cards_face_up(p.hand) >= 2
        end)

      status = if all_done_flipping?, do: :take, else: :flip_2
      game = %Game{game | status: status}
      {:ok, game, players}
    else
      {:ok, game, players}
    end
  end

  # def handle_event(%Game{status: :flip_2} = game, %GameEvent{action: :flip} = event) do
  #   # {player, index} = get_player(game, event.player_id)

  #   if num_cards_face_up(player.hand) < 2 do
  #     players =
  #       List.update_at(game.players, index, fn p ->
  #         hand = flip_card(p.hand, event.hand_index)
  #         Map.put(p, :hand, hand)
  #       end)

  #     all_done_flipping? =
  #       Enum.all?(players, fn p ->
  #         num_cards_face_up(p.hand) >= 2
  #       end)

  #     status = if all_done_flipping?, do: :take, else: :flip_2
  #     game = %Game{game | players: players, status: status}

  #     {:ok, game}
  #   end
  # end

  # def handle_event(%Game{status: :take} = game, %GameEvent{action: :take_from_deck} = event) do
  #   {player, index} = get_player(game, event.player_id)

  #   if is_players_turn(game, player) do
  #     {:ok, card, deck} = deal_from_deck(game.deck)
  #     players = List.update_at(game.players, index, fn p -> %Player{p | held_card: card} end)

  #     {:ok,
  #      game
  #      |> Map.put(:deck, deck)
  #      |> Map.put(:players, players)}
  #   else
  #     {:error, :not_players_turn}
  #   end
  # end

  # def get_player(game, player_id) do
  #   index = Enum.find_index(game.players, fn p -> p.id == player_id end)
  #   player = Enum.at(game.players, index)
  #   {player, index}
  # end

  defp flip_card(hand, index) do
    List.update_at(hand, index, fn card -> Map.put(card, "face_up?", true) end)
  end

  # defp flip_all(hand) do
  #   Enum.map(hand, fn card -> Map.put(card, "face_up?", true) end)
  # end

  # def swap_card(hand, card_name, index) do
  #   old_card = Enum.at(hand, index, %{"name" => card_name, "face_up?" => true})
  # end

  def score(hand) do
    hand
    |> Enum.map(&rank_or_nil/1)
    |> score_ranks(0)
  end

  def playable_cards(%Game{status: :flip2}, %Player{} = player, _) do
    if num_cards_face_up(player.hand) < 2 do
      face_down_cards(player.hand)
    else
      []
    end
  end

  def playable_cards(%Game{} = game, %Player{} = player, num_players)
      when is_players_turn(game, player, num_players) do
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

  def playable_cards(%Game{}, _, _) do
    []
  end

  defp new_deck(1), do: @card_names

  defp new_deck(num_decks) when num_decks > 1 do
    @card_names ++ new_deck(num_decks - 1)
  end

  def new_shuffled_deck() do
    new_deck(@num_decks) |> Enum.shuffle()
  end

  defp deal_from_deck([], _) do
    {:error, :empty_deck}
  end

  defp deal_from_deck(deck, n) when length(deck) < n do
    {:error, :not_enough_cards}
  end

  defp deal_from_deck(deck, n) do
    {cards, deck} = Enum.split(deck, n)
    {:ok, cards, deck}
  end

  defp deal_from_deck(deck) do
    with {:ok, [card], deck} <- deal_from_deck(deck, 1) do
      {:ok, card, deck}
    end
  end

  def num_cards_face_up(hand) do
    Enum.count(hand, fn card -> card["face_up?"] end)
  end

  def face_down_cards(hand) do
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
