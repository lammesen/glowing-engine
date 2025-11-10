defmodule NetAutoWeb.Components.Icon do
  @moduledoc "Lightweight icon helper intended for Heroicons-style glyph names."
  use Phoenix.Component

  alias NetAutoWeb.Components.InputHelpers
  alias Phoenix.HTML

  attr :name, :string, required: true
  attr :label, :string, default: nil
  attr :class, :string, default: ""
  attr :rest, :global

  def icon(assigns) do
    assigns = assign(assigns, :classes, InputHelpers.class_names(["inline-flex items-center", assigns.class]))

    ~H"""
    <span class={@classes} aria-hidden={is_nil(@label)} role="img" aria-label={@label} {@rest}>
      <%= render_svg(@name) %>
    </span>
    """
  end

  defp render_svg("" <> name) do
    # Fallback placeholder renders the icon name for environments without Heroicons.
    HTML.raw(name)
  end
end
