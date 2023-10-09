defmodule GolfWeb.UserAuth do
  import Plug.Conn

  alias Golf.Users
  alias Golf.Users.UserToken

  @salt "_user_auth"
  @user_cookie "_golf_user"
  @cookie_options [same_site: "Lax"]

  def put_user_token(conn, _) do
    session_token = get_session(conn, :user_token)
    cookie_token = get_user_cookie(conn)

    put_user_token(conn, session_token, cookie_token)
  end

  # token in session
  defp put_user_token(conn, session_token, cookie_token) when is_binary(session_token) do
    case verify(session_token) do
      {:ok, token, _} ->
        assign(conn, :user_token, token)
        |> put_resp_cookie(@user_cookie, token, @cookie_options)

      _ ->
        put_user_token(conn, nil, cookie_token)
    end
  end

  # token in cookies
  defp put_user_token(conn, _, cookie_token) when is_binary(cookie_token) do
    case verify(cookie_token) do
      {:ok, token, _} ->
        conn
        |> assign(:user_token, token)
        |> put_session(:user_token, token)

      _ ->
        put_user_token(conn, nil, nil)
    end
  end

  # no token, let's create a user+token and store token in session and cookies
  defp put_user_token(conn, _, _) do
    {_, token} = create_user_and_token()

    conn
    |> assign(:user_token, token)
    |> put_session(:user_token, token)
    |> put_resp_cookie(@user_cookie, token, @cookie_options)
  end

  def verify(user_token) do
    with {:ok, user_id} <- Phoenix.Token.verify(GolfWeb.Endpoint, @salt, user_token) do
      {:ok, user_token, user_id}
    end
  end

  defp get_user_cookie(conn) do
    conn |> Map.get(:cookies) |> Map.get(@user_cookie)
  end

  defp create_user_and_token() do
    {:ok, user} = Users.create_user()
    token = sign(user.id)

    {:ok, _} =
      %UserToken{user_id: user.id, token: token}
      |> Users.insert_user_token()

    {user, token}
  end

  defp sign(data) do
    Phoenix.Token.sign(GolfWeb.Endpoint, @salt, data)
  end
end
