defmodule NetAutoWeb.UserSessionHTML do
  use NetAutoWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:net_auto, NetAuto.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
