defmodule NetAutoWeb.Components.Badge do
  @moduledoc "Small status badge built on top of the DaisyUI badge pattern."
  use Phoenix.Component

  alias NetAutoWeb.Components.InputHelpers

  @variants %{
    "neutral" => "badge-ghost",
    "primary" => "badge-primary",
    "secondary" => "badge-secondary",
    "success" => "badge-success",
    "warning" => "badge-warning",
    "info" => "badge-info",
    "danger" => "badge-error",
    "outline" => "badge-outline"
  }

  attr :variant, :string, default: "neutral"
  attr :class, :string, default: ""
  attr :rest, :global
  slot :inner_block, required: true

  def badge(assigns) do
    assigns = assign(assigns, :classes, classes(assigns))

    ~H"""
    <span class={@classes} {@rest}>
      <%= render_slot(@inner_block) %>
    </span>
    """
  end

  defp classes(assigns) do
    InputHelpers.class_names([
      "badge",
      Map.get(@variants, assigns.variant, @variants["neutral"]),
      assigns.class
    ])
  end
end
