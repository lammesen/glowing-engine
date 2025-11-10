defmodule NetAutoWeb.Components.TextField do
  @moduledoc "Text input with consistent label, hint, and error handling."
  use Phoenix.Component

  alias Phoenix.HTML.FormField
  alias NetAutoWeb.Components.{FormWrapper, InputHelpers}

  attr :field, FormField, default: nil
  attr :label, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :hint, :string, default: nil
  attr :value, :any, default: nil
  attr :disabled, :boolean, default: false
  attr :class, :string, default: ""
  attr :input_class, :string, default: ""
  attr :rest, :global
  slot :actions

  def text_field(assigns) do
    assigns = InputHelpers.normalize(assigns)

    ~H"""
    <FormWrapper.field
      id={@id}
      label={@label}
      hint={@hint}
      errors={@errors}
      class={@class}
    >
      <input
        type="text"
        id={@id}
        name={@name}
        value={@value}
        placeholder={@placeholder}
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
end
