defmodule IchiTest do
  use ExUnit.Case
  doctest Ichi

  test "greets the world" do
    assert Ichi.hello() == :world
  end
end
