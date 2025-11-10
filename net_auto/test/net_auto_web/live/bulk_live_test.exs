defmodule NetAutoWeb.BulkLiveTest do
  use NetAutoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup [:register_and_log_in_user]

  test "redirects unauthenticated visitors", %{conn: _conn} do
    assert {:error, {:redirect, %{to: redirected}}} = live(build_conn(), ~p"/bulk/unauth")
    assert redirected == ~p"/users/log-in"
  end

  test "renders bulk progress page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/bulk/test-ref")
    assert html =~ "Bulk Job"
    assert html =~ "test-ref"
  end

  test "updates when progress events arrive", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/bulk/progress-123")

    send(
      view.pid,
      {:bulk_progress,
       %{bulk_ref: "progress-123", device_id: 42, status: :ok, run_id: 111, error: nil}}
    )

    assert render(view) =~ "#42"
    assert render(view) =~ "OK"

    send(view.pid, {:bulk_summary, %{bulk_ref: "progress-123", ok: 1, error: 0}})
    html = render(view)
    assert html =~ "Completed"
  end
end
