defmodule NetAutoWeb.PageControllerTest do
  use NetAutoWeb.ConnCase

  setup :register_and_log_in_user

  test "GET / requires auth and renders dashboard copy", %{conn: conn, user: user} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ "Welcome back"
    assert html =~ user.email
  end
end
