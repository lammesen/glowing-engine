defmodule NetAutoWeb.PageControllerTest do
  use NetAutoWeb.ConnCase

  describe "authentication" do
    setup :register_and_log_in_user

    test "GET / requires auth and renders dashboard copy", %{conn: conn, user: user} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)
      assert html =~ "Welcome back"
      assert html =~ user.email
    end

    test "GET / redirects when unauthenticated" do
      conn = build_conn() |> get(~p"/")
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end
end
