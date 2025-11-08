defmodule NetAuto.Secrets.Credential do
  @moduledoc """
  Typed credential struct returned by secrets adapters.
  """

  @enforce_keys [:cred_ref]
  defstruct cred_ref: nil,
            username: nil,
            password: nil,
            private_key: nil,
            passphrase: nil,
            metadata: %{}

  @type t :: %__MODULE__{
          cred_ref: String.t(),
          username: String.t() | nil,
          password: String.t() | nil,
          private_key: String.t() | nil,
          passphrase: String.t() | nil,
          metadata: map()
        }
end
