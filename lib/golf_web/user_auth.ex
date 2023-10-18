defmodule GolfWeb.UserAuth do
  import Plug.Conn

  alias Golf.Users
  alias Golf.Users.UserToken

  @salt "_user_auth"
  @user_cookie "_golf_user"
  @cookie_options [same_site: "Lax"]

  defp sign(data) do
    Phoenix.Token.sign(GolfWeb.Endpoint, @salt, data)
  end

  defp verify(user_token) do
    with {:ok, user_id} <- Phoenix.Token.verify(GolfWeb.Endpoint, @salt, user_token),
         true <- Users.user_exists?(user_token) do
      {:ok, user_id}
    end
  end

  defp create_user_and_token() do
    {:ok, user} = Users.create_user()
    token = sign(user.id)

    {:ok, _} =
      %UserToken{user_id: user.id, token: token}
      |> Users.insert_user_token()

    {user, token}
  end

  defp assign_new_user(conn) do
    {_, token} = create_user_and_token()

    conn
    |> assign(:user_token, token)
    |> put_session(:user_token, token)
    |> put_resp_cookie(@user_cookie, token, @cookie_options)
  end

  def put_user_token(conn, _) do
    session_token = get_session(conn, :user_token)
    cookie_token = conn |> Map.get(:cookies) |> Map.get(@user_cookie)

    case {session_token, cookie_token} do
      {nil, nil} ->
        assign_new_user(conn)

      {nil, token} ->
        case verify(token) do
          {:ok, _} ->
            conn
            |> assign(:user_token, token)
            |> put_session(:user_token, token)

          _ ->
            assign_new_user(conn)
        end

      {token, nil} ->
        case verify(token) do
          {:ok, _} ->
            conn
            |> assign(:user_token, token)
            |> put_resp_cookie(@user_cookie, token, @cookie_options)

          _ ->
            assign_new_user(conn)
        end

      _ ->
        case verify(session_token) do
          {:ok, _} ->
            assign(conn, :user_token, session_token)

          _ ->
            assign_new_user(conn)
        end
    end
  end
end
