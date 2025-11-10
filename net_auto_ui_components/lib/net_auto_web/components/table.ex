defmodule NetAutoWeb.Components.Table do
  @moduledoc "Simple data table with declarative column slots."
  use Phoenix.Component

  alias NetAutoWeb.Components.InputHelpers

  attr :rows, :list, default: []
  attr :class, :string, default: ""
  attr :row_class, :string, default: ""
  slot :col, required: true do
    attr :label, :string
  end
  slot :empty

  def table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class={InputHelpers.class_names(["table table-zebra w-full", @class])}>
        <thead>
          <tr>
            <%= for col <- @col do %>
              <th class="text-left text-sm font-semibold text-base-content/70">
                <%= col[:label] || "" %>
              </th>
            <% end %>
          </tr>
        </thead>
        <tbody>
          <%= if Enum.empty?(@rows) do %>
            <tr>
              <td class="py-8 text-center text-base-content/60" colspan={length(@col)}>
                <%= if @empty == [] do %>
                  No results
                <% else %>
                  <%= render_slot(@empty) %>
                <% end %>
              </td>
            </tr>
          <% else %>
            <%= for row <- @rows do %>
              <tr class={InputHelpers.class_names([@row_class])}>
                <%= for col <- @col do %>
                  <td class="align-middle text-sm">
                    <%= render_slot(col, row) %>
                  </td>
                <% end %>
              </tr>
            <% end %>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

end
