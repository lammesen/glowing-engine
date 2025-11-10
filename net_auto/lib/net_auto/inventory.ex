defmodule NetAuto.Inventory do
  @moduledoc """
  Data layer for devices, groups, and command templates.
  """

  import Ecto.Query, warn: false
  alias NetAuto.Repo

  alias NetAuto.Inventory.{
    CommandTemplate,
    Device,
    DeviceGroup,
    DeviceGroupMembership
  }

  alias Phoenix.PubSub

  @device_topic "inventory:devices"
  @sortable_fields ~w(hostname ip protocol site username vendor model inserted_at updated_at)a
  @search_defaults %{query: "", sort_by: :hostname, sort_dir: :asc}

  # Devices -----------------------------------------------------------------

  def list_devices(opts \\ []) do
    Device
    |> maybe_preload(opts)
    |> Repo.all()
  end

  def get_device!(id, opts \\ []) do
    Device
    |> maybe_preload(opts)
    |> Repo.get!(id)
  end

  def create_device(attrs \\ %{}) do
    %Device{}
    |> Device.changeset(attrs)
    |> Repo.insert()
    |> broadcast_device(:created)
  end

  def update_device(%Device{} = device, attrs) do
    device
    |> Device.changeset(attrs)
    |> Repo.update()
    |> broadcast_device(:updated)
  end

  def delete_device(%Device{} = device) do
    device
    |> Repo.delete()
    |> broadcast_device(:deleted)
  end

  def change_device(%Device{} = device, attrs \\ %{}) do
    Device.changeset(device, attrs)
  end

  def search_devices(opts \\ %{}) do
    filters =
      @search_defaults
      |> Map.merge(normalize_filter_opts(opts))
      |> Map.update!(:sort_by, &sanitize_sort_field/1)
      |> Map.update!(:sort_dir, &sanitize_sort_dir/1)

    Device
    |> device_search_query(filters)
    |> Repo.all()
  end

  # Device Groups -----------------------------------------------------------

  def list_device_groups(opts \\ []) do
    DeviceGroup
    |> maybe_preload(opts)
    |> Repo.all()
  end

  def get_device_group!(id, opts \\ []) do
    DeviceGroup
    |> maybe_preload(opts)
    |> Repo.get!(id)
  end

  def create_device_group(attrs \\ %{}) do
    %DeviceGroup{}
    |> DeviceGroup.changeset(attrs)
    |> Repo.insert()
  end

  def update_device_group(%DeviceGroup{} = group, attrs) do
    group
    |> DeviceGroup.changeset(attrs)
    |> Repo.update()
  end

  def delete_device_group(%DeviceGroup{} = group), do: Repo.delete(group)

  def change_device_group(%DeviceGroup{} = group, attrs \\ %{}) do
    DeviceGroup.changeset(group, attrs)
  end

  # Memberships -------------------------------------------------------------

  def list_memberships do
    Repo.all(DeviceGroupMembership)
  end

  def add_device_to_group(attrs) do
    %DeviceGroupMembership{}
    |> DeviceGroupMembership.changeset(attrs)
    |> Repo.insert()
  end

  def update_membership(%DeviceGroupMembership{} = membership, attrs) do
    membership
    |> DeviceGroupMembership.changeset(attrs)
    |> Repo.update()
  end

  def remove_device_from_group(%DeviceGroupMembership{} = membership), do: Repo.delete(membership)

  def change_membership(%DeviceGroupMembership{} = membership, attrs \\ %{}) do
    DeviceGroupMembership.changeset(membership, attrs)
  end

  # Command templates -------------------------------------------------------

  def list_command_templates, do: Repo.all(CommandTemplate)

  def get_command_template!(id), do: Repo.get!(CommandTemplate, id)

  def create_command_template(attrs \\ %{}) do
    %CommandTemplate{}
    |> CommandTemplate.changeset(attrs)
    |> Repo.insert()
  end

  def update_command_template(%CommandTemplate{} = template, attrs) do
    template
    |> CommandTemplate.changeset(attrs)
    |> Repo.update()
  end

  def delete_command_template(%CommandTemplate{} = template), do: Repo.delete(template)

  def change_command_template(%CommandTemplate{} = template, attrs \\ %{}) do
    CommandTemplate.changeset(template, attrs)
  end

  # Helpers -----------------------------------------------------------------

  defp maybe_preload(queryable, opts) do
    case Keyword.get(opts, :preload) do
      nil -> queryable
      preload -> preload(queryable, ^preload)
    end
  end

  defp device_search_query(queryable, %{query: query, sort_by: sort_by, sort_dir: sort_dir}) do
    queryable
    |> apply_query_filter(query)
    |> order_devices(sort_by, sort_dir)
  end

  defp apply_query_filter(queryable, query) when query in [nil, ""], do: queryable

  defp apply_query_filter(queryable, query) do
    pattern = "%#{String.trim(query)}%"

    where(
      queryable,
      [d],
      ilike(d.hostname, ^pattern) or
        ilike(d.ip, ^pattern) or
        ilike(d.vendor, ^pattern) or
        ilike(d.model, ^pattern) or
        ilike(d.site, ^pattern) or
        ilike(d.username, ^pattern) or
        ilike(fragment("?::text", d.tags), ^pattern)
    )
  end

  defp order_devices(queryable, sort_by, sort_dir) do
    order_by(queryable, [d], [{^sort_dir, field(d, ^sort_by)}])
  end

  defp sanitize_sort_field(field) when is_binary(field) do
    field
    |> String.to_existing_atom()
    |> sanitize_sort_field()
  rescue
    ArgumentError -> :hostname
  end

  defp sanitize_sort_field(field) when field in @sortable_fields, do: field
  defp sanitize_sort_field(_field), do: :hostname

  defp sanitize_sort_dir(dir) when dir in [:asc, :desc], do: dir
  defp sanitize_sort_dir("desc"), do: :desc
  defp sanitize_sort_dir("asc"), do: :asc
  defp sanitize_sort_dir(_dir), do: :asc

  @filter_key_map %{"query" => :query, "sort_by" => :sort_by, "sort_dir" => :sort_dir}

  defp normalize_filter_opts(opts) when is_map(opts) do
    Enum.reduce(opts, %{}, fn {key, value}, acc ->
      case normalize_filter_key(key) do
        nil -> acc
        normalized_key -> Map.put(acc, normalized_key, value)
      end
    end)
  end

  defp normalize_filter_opts(opts) when is_list(opts),
    do: opts |> Map.new() |> normalize_filter_opts()

  defp normalize_filter_key(key) when is_atom(key), do: key
  defp normalize_filter_key(key) when is_binary(key), do: Map.get(@filter_key_map, key)
  defp normalize_filter_key(_), do: nil

  defp broadcast_device({:ok, device} = result, action) do
    PubSub.broadcast(NetAuto.PubSub, @device_topic, {:device, action, device})
    result
  end

  defp broadcast_device({:error, _reason} = result, _action), do: result
end
