defmodule Golf.Games.Player do
  use Golf.Schema
  import Ecto.Changeset
  alias Golf.Users.User

  @derive {Jason.Encoder,
           only: [:id, :user_id, :hand, :held_card, :turn, :username, :position, :score]}
  schema "players" do
    belongs_to :game, Golf.Games.Game
    belongs_to :user, Golf.Users.User

    has_many :events, Golf.Games.GameEvent

    field :hand, {:array, :map}, default: []
    field :held_card, :string
    field :turn, :integer

    field :username, :string, virtual: true
    field :position, :string, virtual: true
    field :score, :integer, virtual: true

    timestamps()
  end

  def changeset(player, attrs \\ %{}) do
    player
    |> cast(attrs, [:game_id, :user_id, :hand, :held_card, :turn])
    |> validate_required([:game_id, :user_id, :hand, :turn])
  end

  def new(%User{} = user, turn) do
    %__MODULE__{
      user_id: user.id,
      username: user.username,
      turn: turn
    }
  end
end
