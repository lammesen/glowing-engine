defmodule NetAutoWeb.PageController do
  use NetAutoWeb, :controller

  def home(conn, _params) do
    render(conn, :home, user: conn.assigns.current_user)
  end
end
