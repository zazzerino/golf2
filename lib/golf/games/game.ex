defmodule Golf.Games.Game do
  use Golf.Schema
  import Ecto.Changeset

  @statuses [:init, :flip_2, :take, :hold, :flip, :last_take, :last_hold, :last_flip, :over]
  @card_places [:deck, :table, :held, :hand_0, :hand_1, :hand_2, :hand_3, :hand_4, :hand_5]

  @derive {Jason.Encoder,
           only: [:id, :status, :turn, :deck, :table_cards, :players, :player_id, :playable_cards]}
  schema "games" do
    belongs_to :host, Golf.Users.User

    # has_many :players, Golf.Games.Player
    # has_many :events, Golf.Games.GameEvent

    field :status, Ecto.Enum, values: @statuses, default: :init
    field :turn, :integer, default: 0
    field :deck, {:array, :string}
    field :table_cards, {:array, :string}, default: []
    field :deleted?, :boolean, default: false

    field :players, :map, virtual: true
    field :player_id, :integer, virtual: true
    field :playable_cards, {:array, Ecto.Enum}, values: @card_places, default: [], virtual: true

    timestamps()
  end

  def changeset(game, attrs \\ %{}) do
    game
    |> cast(attrs, [:status, :turn, :deck, :table_cards, :deleted?])
    |> validate_required([:status, :turn, :deck, :table_cards, :deleted?])
  end

  def new(host_id) do
    %__MODULE__{
      host_id: host_id,
      deck: Golf.Games.new_shuffled_deck()
    }
  end
end
