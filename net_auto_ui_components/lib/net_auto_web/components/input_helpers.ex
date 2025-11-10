defmodule NetAutoWeb.Components.InputHelpers do
  @moduledoc false

  import Phoenix.Component, only: [assign_new: 3]
  alias Phoenix.HTML.FormField
  alias Phoenix.Naming

  @doc """
  Normalizes assigns coming from form helpers. Ensures `:id`, `:name`, `:value`,
  and `:errors` keys are always present so downstream components can rely on
  them without defensive checks.
  """
  def normalize(assigns) do
    field = Map.get(assigns, :field)

    assigns
    |> assign_new(:id, fn -> field && field.id end)
    |> assign_new(:name, fn -> field && field.name end)
    |> assign_new(:value, fn ->
      cond do
        Map.has_key?(assigns, :value) -> Map.get(assigns, :value)
        field -> field.value
        true -> nil
      end
    end)
    |> assign_new(:errors, fn -> field_errors(field) end)
    |> assign_new(:label, fn -> derive_label(assigns, field) end)
  end

  def class_names(classes) do
    classes
    |> List.flatten()
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
  end

  def translate_error({msg, opts}), do: replace_tokens(msg, opts)

  defp replace_tokens(msg, opts) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  defp field_errors(%FormField{errors: errors}) when is_list(errors), do: errors
  defp field_errors(_), do: []

  defp derive_label(%{label: label}, _field) when is_binary(label), do: label
  defp derive_label(_assigns, %FormField{field: field}) when not is_nil(field) do
    field |> to_string() |> Naming.humanize()
  end

  defp derive_label(assigns, _field) do
    assigns
    |> Map.get(:name)
    |> case do
      nil -> nil
      name -> name |> to_string() |> Naming.humanize()
    end
  end
end
