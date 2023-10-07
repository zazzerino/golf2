defmodule Golf.Games do
  alias Golf.Repo
  alias Golf.Games.{Game, Player}

  @card_names for rank <- ~w(A 2 3 4 5 6 7 8 9 T J Q K),
                  suit <- ~w(C D H S),
                  do: rank <> suit

  @num_decks 2

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

  # db

  def create_game(host_user_id) do
    deck = new_deck(@num_decks) |> Enum.shuffle()

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:game, %Game{deck: deck})
    |> Ecto.Multi.insert(:player, fn %{game: game} ->
      Ecto.build_assoc(game, :players, %{user_id: host_user_id, turn: 0, host?: true})
    end)
    |> Repo.transaction()
  end
end
