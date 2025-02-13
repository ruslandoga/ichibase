defmodule Ichibase.URL2SQL do
  @moduledoc """
  Not quite entirely unlike PostgREST.
  """

  import Ecto.Query

  @doc """
  Translates a GET request path into an SQL query.

  Examples:

      iex> schema = %{"users" => %{"id" => :integer, "name" => :text}}
      iex> translate("/users?id.eq=123", schema)
      {"SELECT id, name FROM users WHERE id=?", [123]}

  """
  def translate(path, schema) do
    {path, params} =
      case String.split(path, "?") do
        [path] -> {path, []}
        [path, qs] -> {path, URI.query_decoder(qs)}
      end

    [table] = String.split(path, "/", trim: true)

    table_schema =
      Map.get(schema, table) ||
        raise ArgumentError, """
        Table #{table} not found in schema.
        """

    q =
      Enum.reduce(params, from(t in table), fn {key, value}, q ->
        case String.split(key, ".") do
          [column, op] ->
            column_type =
              Map.get(table_schema, column) ||
                raise ArgumentError, """
                Column #{column} not found in schema.
                """

            casted_value = cast_column_value(value, column_type)

            case op do
              # TODO
              "eq" -> where(q, [t], fragment("?=?", literal(^column), ^casted_value))
              _ -> q
            end

          _ ->
            q
        end
      end)

    q =
      with nil <- q.select do
        %{
          q
          | select: %Ecto.Query.SelectExpr{
              expr:
                Enum.map(table_schema, fn {column, _type} ->
                  {{:., [], [{:&, [], [0]}, String.to_atom(column)]}, [], []}
                end)
            }
        }
      end

    Ichibase.Repo.to_sql(:all, q)
  end

  defp cast_column_value(value, :integer), do: String.to_integer(value)
  defp cast_column_value(value, :real), do: String.to_float(value)
  defp cast_column_value(value, :text), do: value
  defp cast_column_value(value, :blob), do: value
end
