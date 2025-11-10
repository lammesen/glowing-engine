defmodule NetAutoUiComponents do
  @moduledoc """
  Entry point for the custom NetAuto UI component library.

  Use `use NetAutoUiComponents` inside LiveViews or components to import the
  helpers defined in this package without wiring each module manually.
  """

  defmacro __using__(_opts) do
    quote do
      alias NetAutoWeb.Components.{
        Badge,
        Button,
        Card,
        DateTimeField,
        EmailField,
        FormWrapper,
        Icon,
        NativeSelect,
        NumberField,
        PasswordField,
        Table,
        TextField,
        TextareaField
      }

      import NetAutoWeb.Components.Badge
      import NetAutoWeb.Components.Button
      import NetAutoWeb.Components.Card
      import NetAutoWeb.Components.DateTimeField
      import NetAutoWeb.Components.EmailField
      import NetAutoWeb.Components.FormWrapper
      import NetAutoWeb.Components.Icon
      import NetAutoWeb.Components.NativeSelect
      import NetAutoWeb.Components.NumberField
      import NetAutoWeb.Components.PasswordField
      import NetAutoWeb.Components.Table
      import NetAutoWeb.Components.TextField
      import NetAutoWeb.Components.TextareaField
    end
  end
end
