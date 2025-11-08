defmodule NetAuto.Secrets.Dummy do
  @moduledoc """
  Default adapter when none configured; always errors.
  """

  @behaviour NetAuto.Secrets

  @impl true
  def fetch(_cred_ref, _opts), do: {:error, :not_configured}
end
