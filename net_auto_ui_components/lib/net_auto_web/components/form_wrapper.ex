defmodule NetAutoWeb.Components.FormWrapper do
  @moduledoc "Reusable wrapping block for form controls (label, hint, errors)."
  use Phoenix.Component

  alias NetAutoWeb.Components.InputHelpers

  attr :id, :string, default: nil
  attr :label, :string, default: nil
  attr :hint, :string, default: nil
  attr :errors, :list, default: []
  attr :class, :string, default: ""
  slot :inner_block, required: true
  slot :actions

  def field(assigns) do
    ~H"""
    <div class={InputHelpers.class_names(["form-control w-full", @class])}>
      <%= if @label do %>
        <label class="label" for={@id}>
          <span class="label-text font-medium"><%= @label %></span>
        </label>
      <% end %>

      <div class="w-full">
        <%= render_slot(@inner_block) %>
      </div>

      <%= if @hint do %>
        <p class="text-sm text-muted mt-1"><%= @hint %></p>
      <% end %>

      <%= for error <- @errors do %>
        <p class="text-error text-sm mt-1" role="alert">
          <%= InputHelpers.translate_error(error) %>
        </p>
      <% end %>

      <%= for action <- @actions do %>
        <div class="mt-2 flex items-center gap-2">
          <%= render_slot(action) %>
        </div>
      <% end %>
    </div>
    """
  end
end
