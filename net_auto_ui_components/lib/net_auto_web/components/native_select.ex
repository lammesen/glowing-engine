defmodule NetAutoWeb.Components.NativeSelect do
  @moduledoc "Standard HTML select with automatic label/error plumbing."
  use Phoenix.Component

  alias Phoenix.HTML.FormField
  alias NetAutoWeb.Components.{FormWrapper, InputHelpers}
  alias Phoenix.Naming

  attr :field, FormField, default: nil
  attr :label, :string, default: nil
  attr :hint, :string, default: nil
  attr :prompt, :string, default: "Select an option"
  attr :options, :list, required: true
  attr :class, :string, default: ""
  attr :input_class, :string, default: ""
  attr :disabled, :boolean, default: false
  attr :rest, :global
  slot :actions

  def native_select(assigns) do
    assigns = InputHelpers.normalize(assigns)
    assigns = assign(assigns, :option_items, normalize_options(assigns.options))

    ~H"""
    <FormWrapper.field
      id={@id}
      label={@label}
      hint={@hint}
      errors={@errors}
      class={@class}
    >
      <select
        id={@id}
        name={@name}
        class={InputHelpers.class_names(["select select-bordered w-full", @input_class])}
        disabled={@disabled}
        {@rest}
      >
        <%= if @prompt do %>
          <option value="" selected={is_nil(@value)}><%= @prompt %></option>
        <% end %>
        <%= for {label, value} <- @option_items do %>
          <option value={value} selected={selected?(value, @value)}>
            <%= label %>
          </option>
        <% end %>
      </select>
      <:actions :if={@actions != []}>
        <%= render_slot(@actions) %>
      </:actions>
    </FormWrapper.field>
    """
  end

  defp normalize_options(options) do
    Enum.map(options, fn
      {label, value} -> {label, value}
      value when is_binary(value) -> {Naming.humanize(value), value}
      value -> {to_string(value), value}
    end)
  end

  defp selected?(value, current) do
    not is_nil(current) and to_string(current) == to_string(value)
  end
end
