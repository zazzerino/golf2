defmodule GolfWeb.UserLiveAuth do
  import Phoenix.Component

  def on_mount(:default, _params, session, socket) do
    with token when is_binary(token) <- session["user_token"],
         user when is_struct(user) <- Golf.Users.get_user_by_token(token) do
      {:cont, assign(socket, :user, user)}
    end
  end
end
