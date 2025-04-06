defmodule Ichi.EndpointTest do
  use ExUnit.Case, async: true

  setup_all do
    {:ok, _finch} = Finch.start_link(name: __MODULE__)
    {:ok, finch: __MODULE__}
  end

  test "GET /", %{finch: finch} do
    req = Finch.build(:get, "http://localhost:4000/")
    resp = Finch.request!(req, finch)
    assert resp.status == 200
    assert resp.body == "Hello, world!"
  end
end
