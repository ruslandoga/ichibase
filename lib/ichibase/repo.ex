defmodule Ichibase.Repo do
  use Ecto.Repo,
    otp_app: :ichibase,
    adapter: Ecto.Adapters.SQLite3
end
