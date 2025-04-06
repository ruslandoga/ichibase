defmodule Ichi.Endpoint do
  @moduledoc false

  def child_spec(opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}, type: :worker}
  end

  def start_link(opts) do
    url = Keyword.fetch!(opts, :url)
    %URI{port: port} = URI.parse(url)
    H1.start_link(port: port, handler: &__MODULE__.handle_request/1)
  end

  @doc false
  def handle_request(%{method: :GET, url: {:abs_path, "/"}}) do
    {200, %{"content-type" => "text/plain"}, "Hello, world!"}
  end

  def handle_request(_other) do
    {404, %{"content-type" => "text/plain"}, "Not Found"}
  end
end
