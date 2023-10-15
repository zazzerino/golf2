defmodule Golf.Games.Game do
  use Golf.Schema
  import Ecto.Changeset

  @statuses [:init, :flip_2, :take, :hold, :flip, :last_take, :last_hold, :last_flip, :over]

  schema "games" do
    belongs_to :host, Golf.Users.User

    has_many :players, Golf.Games.Player
    has_many :events, Golf.Games.GameEvent

    field :status, Ecto.Enum, values: @statuses, default: :init
    field :turn, :integer, default: 0
    field :deck, {:array, :string}
    field :table_cards, {:array, :string}, default: []
    field :deleted?, :boolean, default: false

    timestamps()
  end

  def changeset(game, attrs \\ %{}) do
    game
    |> cast(attrs, [:status, :turn, :deck, :table_cards, :deleted?])
    |> validate_required([:status, :turn, :deck, :table_cards, :deleted?])
  end
end
