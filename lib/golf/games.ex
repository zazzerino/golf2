defmodule Golf.Games do
  alias Golf.Games.{Game, Player}

  @card_names for rank <- ~w(A 2 3 4 5 6 7 8 9 T J Q K),
                  suit <- ~w(C D H S),
                  do: rank <> suit

  @num_decks 2
  @hand_size 6

  def new_deck(1), do: @card_names
  def new_deck(num_decks), do: @card_names ++ new_deck(num_decks - 1)

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

  def create_game(host_user_id) do
    deck = new_deck(@num_decks) |> Enum.shuffle()
    host_player = %Player{user_id: host_user_id, turn: 0, host?: true}
    %Game{deck: deck, players: [host_player]}
  end

  # def start_game(%Game{status: :init} = game) do
  #   # deal hands
  #   num_cards_to_deal = @hand_size * length(game.players)
  #   {cards_to_deal, deck} = Enum.split(game.deck, num_cards_to_deal)

  #   hands =
  #     cards_to_deal
  #     |> Enum.map(fn card_name -> %{"name" => card_name, "face_up?" => false} end)
  #     |> Enum.chunk_every(@hand_size)
  # end
end
