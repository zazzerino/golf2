defmodule GolfWeb.Plugs do
  import Plug.Conn

  alias Golf.Users
  alias Golf.Users.UserToken

  @salt "user_auth"
  @user_cookie "_golf_user"
  @cookie_options [same_site: "Lax"]

  def put_user_token(conn, _) do
    cond do
      # check if token in session
      token = get_session(conn, :user_token) ->
        case verify(token) do
          {:ok, _} ->
            assign(conn, :user_token, token)
        end

      # check if token in cookies
      token = conn |> Map.get(:cookies) |> Map.get(@user_cookie) ->
        case verify(token) do
          {:ok, _} ->
            conn
            |> assign(:user_token, token)
            |> put_session(:user_token, token)
        end

      # otherwise, create a new user and store a token in cookies
      true ->
        {:ok, user} = Users.create_user()
        token = sign(user.id)

        {:ok, _} =
          %UserToken{user_id: user.id, token: token}
          |> Users.insert_user_token()

        conn
        |> assign(:user_token, token)
        |> put_session(:user_token, token)
        |> put_resp_cookie(@user_cookie, token, @cookie_options)
    end
  end

  defp sign(data), do: Phoenix.Token.sign(GolfWeb.Endpoint, @salt, data)

  defp verify(token), do: Phoenix.Token.verify(GolfWeb.Endpoint, @salt, token)
end
