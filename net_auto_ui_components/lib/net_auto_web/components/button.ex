defmodule NetAutoWeb.Components.Button do
  @moduledoc "Accessible button primitive with variant + size helpers."
  use Phoenix.Component

  alias NetAutoWeb.Components.InputHelpers

  @variants %{
    "primary" => "btn-primary",
    "secondary" => "btn-secondary",
    "ghost" => "btn-ghost",
    "outline" => "btn-outline",
    "link" => "btn-link",
    "danger" => "btn-error",
    "success" => "btn-success"
  }

  @sizes %{
    "xs" => "btn-xs",
    "sm" => "btn-sm",
    "md" => "btn-md",
    "lg" => "btn-lg"
  }

  attr :type, :string, default: "button"
  attr :variant, :string, default: "primary"
  attr :size, :string, default: "md"
  attr :class, :string, default: ""
  attr :disabled, :boolean, default: false
  attr :loading, :boolean, default: false
  attr :icon_only, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  def button(assigns) do
    assigns = assign(assigns, :classes, classes(assigns))

    ~H"""
    <button type={@type} class={@classes} disabled={@disabled} {@rest}>
      <%= if @loading do %>
        <span class="loading loading-spinner"></span>
      <% end %>
      <span class={InputHelpers.class_names([@icon_only && "sr-only"]) }>
        <%= render_slot(@inner_block) %>
      </span>
    </button>
    """
  end

  defp classes(assigns) do
    InputHelpers.class_names([
      "btn",
      Map.get(@variants, assigns.variant, @variants["primary"]),
      Map.get(@sizes, assigns.size, @sizes["md"]),
      assigns.loading && "loading",
      assigns.class
    ])
  end
end
