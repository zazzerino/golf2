defmodule Golf.Games do
  alias Golf.Users.User
  alias Golf.Games.{Game, Player, GameEvent}

  @card_names for rank <- ~w(A 2 3 4 5 6 7 8 9 T J Q K),
                  suit <- ~w(C D H S),
                  do: rank <> suit

  @num_decks 2
  @hand_size 6

  defguard is_players_turn(game, player)
           when game.status == :flip_2 or
                  rem(game.turn, length(game.players)) == player.turn

  def create_game(%User{} = host) do
    player = %Player{
      turn: 0,
      user_id: host.id,
      username: host.username
    }

    %Game{
      host_id: host.id,
      deck: new_shuffled_deck(),
      players: [player]
    }
  end

  def start_game(%Game{status: :init} = game) do
    # deal hands to players
    num_cards_to_deal = @hand_size * length(game.players)
    {:ok, card_names, deck} = deal_from_deck(game.deck, num_cards_to_deal)

    hands =
      card_names
      |> Enum.map(fn name -> %{"name" => name, "face_up?" => false} end)
      |> Enum.chunk_every(@hand_size)

    players =
      game.players
      |> Enum.with_index()
      |> Enum.map(fn {player, index} ->
        Map.put(player, :hand, Enum.at(hands, index))
      end)

    # deal table card
    {:ok, card, deck} = deal_from_deck(deck)
    table_cards = [card | game.table_cards]

    game = %Game{game | status: :flip_2, deck: deck, table_cards: table_cards, players: players}
    {:ok, game}
  end

  def get_player(players, player_id) do
    index = Enum.find_index(players, fn p -> p.id == player_id end)
    player = Enum.at(players, index)
    {player, index}
  end

  def handle_event(
        %Game{status: :flip_2} = game,
        %GameEvent{action: :flip} = event,
        {%Player{} = player, player_index}
      ) do
    if num_cards_face_up(player.hand) < 2 do
      hand = flip_card(player.hand, event.hand_index)
      players = List.update_at(game.players, player_index, &Map.put(&1, :hand, hand))

      all_done_flipping? =
        Enum.all?(players, fn p ->
          num_cards_face_up(p.hand) >= 2
        end)

      status = if all_done_flipping?, do: :take, else: :flip_2
      game = %Game{game | status: status, players: players}
      {:ok, game}
    else
      {:error, :already_flipped}
    end
  end

  def handle_event(
        %Game{status: :take} = game,
        %GameEvent{action: :take_from_deck},
        {_, player_index}
      ) do
    {:ok, card, deck} = deal_from_deck(game.deck)
    players = List.update_at(game.players, player_index, &Map.put(&1, :held_card, card))
    game = %Game{game | status: :hold, deck: deck, players: players}
    {:ok, game}
  end

  def handle_event(
        %Game{status: :last_take} = game,
        %GameEvent{action: :take_from_deck} = event,
        {%Player{} = player, player_index}
      ) do
    with take_game <- Map.put(game, :status, :take),
         {:ok, game} <- handle_event(take_game, event, {player, player_index}),
         game <- Map.put(game, :status, :last_hold) do
      {:ok, game}
    end
  end

  def handle_event(
        %Game{status: :take} = game,
        %GameEvent{action: :take_from_table},
        {_, player_index}
      ) do
    [card | table_cards] = game.table_cards
    players = List.update_at(game.players, player_index, &Map.put(&1, :held_card, card))
    game = %Game{game | status: :hold, table_cards: table_cards, players: players}
    {:ok, game}
  end

  def handle_event(
        %Game{status: :last_take} = game,
        %GameEvent{action: :take_from_table} = event,
        {%Player{} = player, player_index}
      ) do
    with take_game <- Map.put(game, :status, :take),
         {:ok, game} <- handle_event(take_game, event, {player, player_index}),
         game <- Map.put(game, :status, :last_hold) do
      {:ok, game}
    end
  end

  def handle_event(
        %Game{status: :hold} = game,
        %GameEvent{action: :discard},
        {%Player{} = player, player_index}
      ) do
    card = player.held_card
    table_cards = [card | game.table_cards]

    {status, turn} =
      if num_cards_face_up(player.hand) == 5 do
        {:take, game.turn + 1}
      else
        {:flip, game.turn}
      end

    players = List.update_at(game.players, player_index, &Map.put(&1, :held_card, nil))
    game = %Game{game | status: status, turn: turn, table_cards: table_cards, players: players}
    {:ok, game}
  end

  def handle_event(
        %Game{status: :last_hold} = game,
        %GameEvent{action: :discard},
        {%Player{} = player, player_index}
      ) do
    card = player.held_card
    table_cards = [card | game.table_cards]
    {_, other_players} = List.pop_at(game.players, player_index)

    {status, turn, hand} =
      if Enum.all?(other_players, &all_face_up?(&1.hand)) do
        {:over, game.turn, flip_all(player.hand)}
      else
        {:last_take, game.turn + 1, player.hand}
      end

    players = List.update_at(game.players, player_index, &Map.put(&1, :hand, hand))
    game = %Game{game | status: status, turn: turn, table_cards: table_cards, players: players}
    {:ok, game}
  end

  def handle_event(
        %Game{status: :hold} = game,
        %GameEvent{action: :swap} = event,
        {%Player{} = player, player_index}
      ) do
    {card, hand} = swap_card(player.hand, player.held_card, event.hand_index)
    table_cards = [card | game.table_cards]

    players =
      List.update_at(game.players, player_index, fn player ->
        player |> Map.put(:hand, hand) |> Map.put(:held_card, nil)
      end)

    {status, turn} =
      cond do
        Enum.all?(players, &all_face_up?(&1.hand)) ->
          {:over, game.turn}

        all_face_up?(hand) ->
          {:last_take, game.turn + 1}

        true ->
          {:take, game.turn + 1}
      end

    game = %Game{game | status: status, turn: turn, table_cards: table_cards, players: players}
    {:ok, game}
  end

  def handle_event(
        %Game{status: :flip} = game,
        %GameEvent{action: :flip} = event,
        {%Player{} = player, player_index}
      ) do
    players =
      List.update_at(game.players, player_index, fn p ->
        hand = flip_card(p.hand, event.hand_index)
        Map.put(p, :hand, hand)
      end)

    {status, turn} =
      cond do
        Enum.all?(players, fn p -> all_face_up?(p.hand) end) ->
          {:over, game.turn}

        all_face_up?(player.hand) ->
          {:last_take, game.turn + 1}

        true ->
          {:take, game.turn + 1}
      end

    game = %Game{game | status: status, turn: turn, players: players}
    {:ok, game}
  end

  def playable_cards(%Game{status: :flip_2}, %Player{} = player) do
    if num_cards_face_up(player.hand) < 2 do
      face_down_cards(player.hand)
    else
      []
    end
  end

  def playable_cards(%Game{} = game, %Player{} = player) when is_players_turn(game, player) do
    case game.status do
      :flip ->
        face_down_cards(player.hand)

      s when s in [:take, :last_take] ->
        [:deck, :table]

      s when s in [:hold, :last_hold] ->
        [:held, :hand_0, :hand_1, :hand_2, :hand_3, :hand_4, :hand_5]

      _ ->
        []
    end
  end

  def playable_cards(%Game{}, _), do: []

  def score(hand) do
    hand
    |> Enum.map(&rank_or_nil/1)
    |> score_ranks(0)
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

  defp flip_card(hand, index) do
    List.update_at(hand, index, fn card ->
      Map.put(card, "face_up?", true)
    end)
  end

  defp swap_card(hand, card_name, index) do
    old_card_name = Enum.at(hand, index) |> Map.get("name")
    hand = List.replace_at(hand, index, %{"name" => card_name, "face_up?" => true})
    {old_card_name, hand}
  end

  defp flip_all(hand) do
    Enum.map(hand, fn card -> Map.put(card, "face_up?", true) end)
  end

  defp num_cards_face_up(hand) do
    Enum.count(hand, fn card -> card["face_up?"] end)
  end

  defp all_face_up?(hand) do
    num_cards_face_up(hand) == @hand_size
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
