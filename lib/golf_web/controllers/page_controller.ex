defmodule GolfWeb.PageController do
  use GolfWeb, :controller

  def home(conn, _params) do
    user_id = conn.assigns.user_id
    render(conn, :home, page_title: "Home", user_id: user_id)
  end
end
