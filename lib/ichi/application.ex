defmodule Ichi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # {Ichi.S3,
      #  url: "http://localhost:9000/ichi",
      #  access_key_id: "minioadmin",
      #  secret_access_key: "minioadmin"},
      # {Ichi.Repo, path: "./ichi.db"},
      {Ichi.Endpoint, url: "http://localhost:4000"}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Ichi.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
