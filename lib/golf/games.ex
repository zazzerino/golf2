defmodule Golf.Games do
  alias Golf.Games.{Game, Player}

  @card_names for rank <- ~w(A 2 3 4 5 6 7 8 9 T J Q K),
                  suit <- ~w(C D H S),
                  do: rank <> suit

  @num_decks 2
  @hand_size 6

  def new_deck(1), do: @card_names
  def new_deck(num_decks) when num_decks > 1, do: @card_names ++ new_deck(num_decks - 1)

  def deal_from_deck([], _) do
    {:error, :empty_deck}
  end

  def deal_from_deck(deck, n) when length(deck) < n do
    {:error, :not_enough_cards}
  end

  def deal_from_deck(deck, n) do
    {dealt_cards, deck} = Enum.split(deck, n)
    {:ok, dealt_cards, deck}
  end

  def deal_from_deck(deck) do
    with {:ok, [card], deck} <- deal_from_deck(deck, 1) do
      {:ok, card, deck}
    end
  end

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
end
