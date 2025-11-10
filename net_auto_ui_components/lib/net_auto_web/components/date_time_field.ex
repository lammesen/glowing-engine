defmodule NetAutoWeb.Components.DateTimeField do
  @moduledoc "Wrapper around the native `datetime-local` input."
  use Phoenix.Component

  alias Phoenix.HTML.FormField
  alias NetAutoWeb.Components.{FormWrapper, InputHelpers}

  attr :field, FormField, default: nil
  attr :label, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :hint, :string, default: nil
  attr :value, :any, default: nil
  attr :min, :string, default: nil
  attr :max, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :class, :string, default: ""
  attr :input_class, :string, default: ""
  attr :rest, :global
  slot :actions

  def date_time_field(assigns) do
    assigns = InputHelpers.normalize(assigns)
    assigns = assign(assigns, :value, normalize_value(assigns.value))

    ~H"""
    <FormWrapper.field
      id={@id}
      label={@label}
      hint={@hint}
      errors={@errors}
      class={@class}
    >
      <input
        type="datetime-local"
        id={@id}
        name={@name}
        value={@value}
        placeholder={@placeholder}
        min={@min}
        max={@max}
        class={InputHelpers.class_names(["input input-bordered w-full", @input_class])}
        disabled={@disabled}
        {@rest}
      />
      <:actions :if={@actions != []}>
        <%= render_slot(@actions) %>
      </:actions>
    </FormWrapper.field>
    """
  end

  defp normalize_value(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  defp normalize_value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp normalize_value(value), do: value
end
