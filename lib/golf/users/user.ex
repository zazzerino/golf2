defmodule Golf.Users.User do
  use Golf.Schema
  import Ecto.Changeset

  @default_username "user"

  @derive {Jason.Encoder, only: [:id, :username]}
  schema "users" do
    field :username, :string, default: @default_username
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username])
    |> validate_required([:username])
  end
end
