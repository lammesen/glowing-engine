defmodule NetAutoWeb.PageController do
  use NetAutoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
