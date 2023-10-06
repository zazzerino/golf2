defmodule GolfWeb.Plugs do
  import Plug.Conn
  alias Golf.Users
  alias Golf.Users.UserToken

  @salt "_golf_salt_7871312168151543"
  @user_cookie "_golf_user"
  @cookie_options [sign: true, same_site: "Lax"]

  def fetch_user(conn, _opts) do
    # check if token in session
    if token = get_session(conn, :user_token) do
      get_user_and_assign_to_conn(conn, token)
    else
      # check if token in cookies
      conn = fetch_cookies(conn, signed: @user_cookie)

      if token = conn.cookies[@user_cookie] do
        get_user_and_assign_to_conn(conn, token)
        |> put_session(:user_token, token)
      else
        # otherwise, create a new user and token
        {:ok, user} = Users.create_user()

        token = Phoenix.Token.sign(conn, @salt, user.id)
        user_token = %UserToken{user_id: user.id, token: token}
        {:ok, _} = Users.insert_user_token(user_token)

        assign_user_to_conn(conn, user.id, token)
        |> put_session(:user_token, token)
        |> put_resp_cookie(@user_cookie, token, @cookie_options)
      end
    end
  end

  defp get_user_and_assign_to_conn(conn, token) do
    user = Users.get_user_by_token(token)
    assign_user_to_conn(conn, user.id, token)
  end

  defp assign_user_to_conn(conn, user_id, token) do
    conn
    |> assign(:user_id, user_id)
    |> assign(:user_token, token)
  end
end