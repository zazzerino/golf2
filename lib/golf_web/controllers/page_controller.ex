defmodule GolfWeb.PageController do
  use GolfWeb, :controller

  def home(conn, _params) do
    token = conn.assigns.user_token
    user = Golf.Users.get_user_by_token(token)
    render(conn, :home, page_title: "Home", user: user)
  end
end
