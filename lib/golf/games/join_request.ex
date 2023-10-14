defmodule Golf.Games.JoinRequest do
  use Golf.Schema
  import Ecto.Changeset
  alias Golf.Users.User

  schema "join_requests" do
    belongs_to :game, Golf.Games.Game
    belongs_to :user, Golf.Users.User

    field :confirmed?, :boolean, default: false
    field :username, :string, virtual: true

    timestamps()
  end

  def changeset(join_request, attrs \\ %{}) do
    join_request
    |> cast(attrs, [:game_id, :user_id, :confirmed?])
    |> validate_required([:game_id, :user_id, :confirmed?])
  end

  def new(game_id, %User{} = user) when is_integer(game_id) do
    %__MODULE__{game_id: game_id, user_id: user.id, username: user.username}
  end
end
