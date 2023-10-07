defmodule GolfWeb.PageController do
  use GolfWeb, :controller

  def home(conn, _params) do
    user = conn.assigns.user
    render(conn, :home, page_title: "Home", user: user)
  end
end
