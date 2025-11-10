defmodule NetAutoWeb.Plugs.ContentSecurityPolicy do
  @moduledoc """
  Plug that applies the repo-wide Content-Security-Policy header.
  Defaults to the same policy documented in SECURITY_REPORT.md and can be
  overridden via the `:policy` option when used.
  """

  @behaviour Plug
  import Plug.Conn

  @default_policy "default-src 'self'; img-src 'self' data:; script-src 'self'; style-src 'self' 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'"

  @impl Plug
  def init(opts), do: Keyword.get(opts, :policy, @default_policy)

  @impl Plug
  def call(conn, policy) do
    put_resp_header(conn, "content-security-policy", policy)
  end
end
