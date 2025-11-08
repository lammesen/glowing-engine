defmodule NetAutoWeb.DeviceLiveTest do
  use NetAutoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias NetAuto.InventoryFixtures
  alias NetAuto.Repo
  alias Oban.Job

  setup [:register_and_log_in_user, :clear_jobs]

  defp clear_jobs(_) do
    Repo.delete_all(Job)
    :ok
  end

  describe "index" do
    test "lists devices and supports unified search", %{conn: conn} do
      InventoryFixtures.device_fixture(%{hostname: "alpha", site: "lab"})
      InventoryFixtures.device_fixture(%{hostname: "bravo", site: "dc1"})

      {:ok, view, html} = live(conn, ~p"/devices")
      assert html =~ "Devices"
      assert html =~ "alpha"
      assert html =~ "bravo"

      view
      |> form("#device-search-form", %{"q" => "alpha"})
      |> render_change()

      refute render(view) =~ "bravo"
      assert render(view) =~ "alpha"
    end

    test "opens modal to add a device and persists it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/devices")

      view |> element("button", "Add Device") |> render_click()
      assert_patch(view, ~p"/devices/new")

      params = %{
        "hostname" => "modal-sw",
        "ip" => "10.0.0.5",
        "protocol" => "ssh",
        "port" => "22",
        "username" => "ops",
        "cred_ref" => "LAB"
      }

      view
      |> form("#device-form", %{"device" => params})
      |> render_submit()

      html = render(view)
      assert html =~ "Device saved"
      assert html =~ "modal-sw"
    end

    test "edits an existing device from the modal", %{conn: conn} do
      device = InventoryFixtures.device_fixture(%{hostname: "edge-old"})

      {:ok, view, _html} = live(conn, ~p"/devices")
      view
      |> element("[data-role=edit][data-device-id=\"#{device.id}\"]")
      |> render_click()
      assert_patch(view, ~p"/devices/#{device.id}/edit")

      view
      |> form("#device-form", %{"device" => %{"hostname" => "edge-new"}})
      |> render_submit()

      html = render(view)
      assert html =~ "Device updated"
      assert html =~ "edge-new"
    end

    test "selecting devices enables bulk command modal", %{conn: conn} do
      device = InventoryFixtures.device_fixture()

      {:ok, view, html} = live(conn, ~p"/devices")
      assert html =~ "Run Bulk Command"
      assert html =~ "disabled"

      view |> element("#device-select-#{device.id}") |> render_click()
      html = render(view)
      refute html =~ "Run Bulk Command" <> ~s( disabled)
    end

    test "submitting bulk command enqueues jobs and redirects", %{conn: conn} do
      device = InventoryFixtures.device_fixture()

      {:ok, view, _html} = live(conn, ~p"/devices")
      view |> element("#device-select-#{device.id}") |> render_click()
      view |> element("#bulk-run-button") |> render_click()
      assert_patch(view, ~p"/devices/bulk")

      view
      |> form("#bulk-command-form", %{"command" => "show version"})
      |> render_submit()

      job = Repo.one(Job)
      assert job
      bulk_ref = job.args["bulk_ref"]
      assert_redirect(view, ~p"/bulk/#{bulk_ref}")
    end

    test "receives PubSub updates for device changes", %{conn: conn} do
      device = InventoryFixtures.device_fixture(%{hostname: "pubsub"})
      {:ok, view, _html} = live(conn, ~p"/devices")

      Phoenix.PubSub.broadcast(NetAuto.PubSub, "inventory:devices", {:device, :created, device})
      Process.sleep(10)

      assert render(view) =~ "pubsub"
    end
  end
end
