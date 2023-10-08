defmodule GolfWeb.Plugs do
  import Plug.Conn
  alias Golf.Users
  alias Golf.Users.UserToken

  @salt "user_auth"
  @user_cookie "_golf_user"
  @cookie_options [sign: true, same_site: "Lax"]

  def put_user(conn, _opts) do
    cond do
      # check if token is in session
      token = get_session(conn, :user_token) ->
        user = Users.get_user_by_token(token)
        assign(conn, :user, user)

      # check if token is in cookies
      token =
          fetch_cookies(conn, signed: @user_cookie) |> Map.get(:cookies) |> Map.get(@user_cookie) ->
        user = Users.get_user_by_token(token)

        conn
        |> assign(:user, user)
        |> put_session(:user_token, token)

      # otherwise, create a new user and store a token in cookies
      true ->
        {:ok, user} = Users.create_user()
        token = Phoenix.Token.sign(conn, @salt, user.id)

        {:ok, _} =
          %UserToken{user_id: user.id, token: token}
          |> Users.insert_user_token()

        conn
        |> assign(:user, user)
        |> put_session(:user_token, token)
        |> put_resp_cookie(@user_cookie, token, @cookie_options)
    end
  end
end
