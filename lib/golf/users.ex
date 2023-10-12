defmodule Golf.Users do
  import Ecto.Query, warn: false

  alias Golf.Repo
  alias Golf.Users.{User, UserToken}

  def get_user(user_id) do
    Repo.get(User, user_id)
  end

  def get_user_by_token(token) do
    from(t in UserToken,
      where: [token: ^token],
      join: u in assoc(t, :user),
      select: u
    )
    |> Repo.one()
  end

  def create_user() do
    Repo.insert(%User{})
  end

  def insert_user_token(token) do
    Repo.insert(token)
  end

  def user_exists?(token) when is_binary(token) do
    from(ut in UserToken, where: [token: ^token])
    |> Repo.exists?()
  end

  # def get_username(user_id) do
  #   from(u in User,
  #     where: [id: ^user_id],
  #     select: u.username
  #   )
  #   |> Repo.one()
  # end

  # def update_username(user_id, new_name) do
  #   from(u in User, where: [id: ^user_id])
  #   |> Repo.update_all(set: [username: new_name])
  # end
end
