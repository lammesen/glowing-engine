defmodule NetAutoWeb.Components.TextareaField do
  @moduledoc "Textarea input with consistent styling."
  use Phoenix.Component

  alias Phoenix.HTML.FormField
  alias NetAutoWeb.Components.{FormWrapper, InputHelpers}

  attr :field, FormField, default: nil
  attr :label, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :hint, :string, default: nil
  attr :value, :any, default: nil
  attr :rows, :integer, default: 4
  attr :disabled, :boolean, default: false
  attr :class, :string, default: ""
  attr :input_class, :string, default: ""
  attr :rest, :global
  slot :actions

  def textarea_field(assigns) do
    assigns = InputHelpers.normalize(assigns)

    ~H"""
    <FormWrapper.field
      id={@id}
      label={@label}
      hint={@hint}
      errors={@errors}
      class={@class}
    >
      <textarea
        id={@id}
        name={@name}
        rows={@rows}
        placeholder={@placeholder}
        class={InputHelpers.class_names(["textarea textarea-bordered w-full", @input_class])}
        disabled={@disabled}
        {@rest}
      ><%= @value %></textarea>
      <:actions :if={@actions != []}>
        <%= render_slot(@actions) %>
      </:actions>
    </FormWrapper.field>
    """
  end
end
