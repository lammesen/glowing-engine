defmodule NetAutoWeb.BulkLiveTest do
  use NetAutoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup [:register_and_log_in_user]

  test "redirects unauthenticated visitors" do
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

  test "ignores events for other refs", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/bulk/main")

    send(view.pid, {:bulk_progress, %{bulk_ref: "other", device_id: 1, status: :ok}})
    refute render(view) =~ "#1"

    send(view.pid, {:bulk_summary, %{bulk_ref: "other", ok: 5, error: 1}})
    html = render(view)
    assert html =~ "Completed"
    assert html =~ "0"
  end

  test "shows run link and errors in table", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/bulk/runlink")

    Phoenix.PubSub.broadcast(NetAuto.PubSub, "bulk:runlink", {
      :bulk_progress,
      %{bulk_ref: "runlink", device_id: 7, status: :error, run_id: 999, error: "timeout"}
    })

    html = render(view)
    assert html =~ "ERROR"
    assert html =~ "timeout"
    assert html =~ "/devices/7"
  end
end
