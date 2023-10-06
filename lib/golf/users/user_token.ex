defmodule Golf.Users.UserToken do
  use Golf.Schema

  schema "users_tokens" do
    belongs_to :user, Golf.Users.User
    field :token, :binary
    timestamps(updated_at: false)
  end
end