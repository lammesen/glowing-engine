defmodule NetAutoWeb.Components.Card do
  @moduledoc "Composable card layout helpers."
  use Phoenix.Component

  alias NetAutoWeb.Components.InputHelpers

  attr :class, :string, default: ""
  attr :body_class, :string, default: ""
  slot :title
  slot :subtitle
  slot :actions
  slot :inner_block
  slot :footer

  def card(assigns) do
    ~H"""
    <div class={InputHelpers.class_names(["card bg-base-100 shadow", @class])}>
      <%= if @title != [] or @actions != [] do %>
        <div class="card-title flex items-center justify-between gap-4 p-4 pb-0">
          <div>
            <%= for title <- @title do %>
              <p class="text-lg font-semibold leading-tight"><%= render_slot(title) %></p>
            <% end %>
            <%= for subtitle <- @subtitle do %>
              <p class="text-sm text-muted"><%= render_slot(subtitle) %></p>
            <% end %>
          </div>
          <div class="flex items-center gap-2">
            <%= for action <- @actions do %>
              <%= render_slot(action) %>
            <% end %>
          </div>
        </div>
      <% end %>

      <div class={InputHelpers.class_names(["card-body", @body_class])}>
        <%= render_slot(@inner_block) %>
      </div>

      <%= for footer <- @footer do %>
        <div class="card-actions border-t border-base-200 px-6 py-4">
          <%= render_slot(footer) %>
        </div>
      <% end %>
    </div>
    """
  end
end
