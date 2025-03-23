defmodule Ichibase.URL2SQLTest do
  use ExUnit.Case, async: true
  alias Ichibase.URL2SQL

  test "it works" do
    schema = %{"users" => %{"id" => :integer, "name" => :text}}

    assert URL2SQL.translate("/users?id=lt.123", schema) ==
             {"""
              SELECT u0."id", u0."name" FROM "users" AS u0 WHERE (u0."id" < ?)\
              """, [123]}

    assert URL2SQL.translate("/users?id=gte.123&name=eq.hello", schema) ==
             {"""
              SELECT u0."id", u0."name" FROM "users" AS u0 WHERE (u0."id" >= ?) AND (u0."name" = ?)\
              """, [123, "hello"]}
  end
end
