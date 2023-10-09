defmodule Golf.Games.Player do
  use Golf.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :user_id, :hand, :held_card, :turn, :username, :score]}
  schema "players" do
    belongs_to :game, Golf.Games.Game
    belongs_to :user, Golf.Users.User

    has_many :events, Golf.Games.Event

    field :hand, {:array, :map}, default: []
    field :held_card, :string
    field :turn, :integer

    field :username, :string, virtual: true
    field :score, :integer, virtual: true

    timestamps()
  end

  def changeset(player, attrs) do
    player
    |> cast(attrs, [:game_id, :user_id, :hand, :held_card, :turn])
    |> validate_required([:game_id, :user_id, :hand, :turn])
  end
end
