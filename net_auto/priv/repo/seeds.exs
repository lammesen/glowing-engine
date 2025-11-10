alias NetAuto.{Inventory, Repo}
alias NetAuto.Inventory.Device

if not function_exported?(Inventory, :create_device, 1) do
  raise "NetAuto.Inventory.create_device/1 is unavailable. Did you run `mix deps.get` and compile?"
end

sim_username =
  System.get_env("NET_AUTO_LAB_SIM_USERNAME") ||
    System.get_env("NETAUTO_SIM_USER") ||
    "netops"

sim_cred_ref =
  System.get_env("NET_AUTO_SIM_CRED_REF") ||
    System.get_env("NETAUTO_SIM_CRED_REF") ||
    "env:LAB_SIM"

# Seed 10 simulator-backed devices that point to localhost SSH ports 2201-2210.
# Before running this script, start the Docker lab via `bin/launch-cisco-sims.sh`.

defmodule SeedHelpers do
  def device_attrs do
    [
      {"LAB-R1", "SITE-A", "10.10.0.1", 2201},
      {"LAB-R2", "SITE-A", "10.10.0.2", 2202},
      {"LAB-R3", "SITE-B", "10.10.0.3", 2203},
      {"LAB-R4", "SITE-B", "10.10.0.4", 2204},
      {"LAB-R5", "SITE-C", "10.10.0.5", 2205},
      {"LAB-R6", "SITE-C", "10.10.0.6", 2206},
      {"LAB-R7", "SITE-D", "10.10.0.7", 2207},
      {"LAB-R8", "SITE-D", "10.10.0.8", 2208},
      {"LAB-R9", "SITE-E", "10.10.0.9", 2209},
      {"LAB-R10", "SITE-E", "10.10.0.10", 2210}
    ]
  end
end

Enum.each(SeedHelpers.device_attrs(), fn {hostname, site, mgmt_ip, port} ->
  case Repo.get_by(Device, hostname: hostname) do
    nil ->
      attrs = %{
        hostname: hostname,
        ip: "127.0.0.1",
        port: port,
        protocol: :ssh,
        username: sim_username,
        cred_ref: sim_cred_ref,
        vendor: "cisco",
        model: "simulator",
        site: site,
        tags: %{"mgmt_ip" => mgmt_ip, "sim_port" => port},
        metadata: %{"simulator" => true}
      }

      case Inventory.create_device(attrs) do
        {:ok, device} -> IO.puts("Inserted #{device.hostname} (port #{port})")
        {:error, changeset} -> IO.inspect(changeset.errors, label: "Failed to insert #{hostname}")
      end

    %Device{} ->
      IO.puts("Skipping #{hostname}; already exists")
  end
end)
