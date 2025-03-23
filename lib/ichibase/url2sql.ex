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
      Enum.reduce(params, from(t in table), fn
        # https://docs.postgrest.org/en/v12/references/api/tables_views.html#ordering
        {"order", order}, q ->
          nil

        {"limit", limit}, q ->
          limit = String.to_integer(limit)
          limit(q, ^limit)

        {"offset", offset}, q ->
          offset = String.to_integer(offset)
          offset(q, ^offset)

        # TODO type casting
        # TODO joins https://docs.postgrest.org/en/v12/references/api/resource_embedding.html#many-to-one-relationships
        {"select", select}, q ->
          select_fields =
            select
            |> String.split(",", trim: true)
            |> Enum.map(fn field ->
              case String.split(field, ":") do
                [select_as, column] -> {select_as, column}
                [column] -> {column, column}
              end
            end)

          Enum.reduce(select_fields, q, fn {select_as, column}, q ->
            Map.fetch!(table_schema, column)
            select_merge(q, [t], %{^select_as => field(t, ^column)})
          end)

        {key, value}, q ->
          case [key | String.split(value, ".")] do
            # https://docs.postgrest.org/en/v12/references/api/tables_views.html#operators
            [column, op, value]
            when op in ["eq", "gt", "gte", "lt", "lte", "neq", "like", "ilike"] ->
              {column, value} = cast_column_value(table_schema, column, value)

              # TODO match, imatch
              case op do
                "eq" -> where(q, [t], field(t, ^column) == ^value)
                "gt" -> where(q, [t], field(t, ^column) > ^value)
                "gte" -> where(q, [t], field(t, ^column) >= ^value)
                "lt" -> where(q, [t], field(t, ^column) < ^value)
                "lte" -> where(q, [t], field(t, ^column) <= ^value)
                "neq" -> where(q, [t], field(t, ^column) != ^value)
                "like" -> where(q, [t], like(field(t, ^column), ^value))
                "ilike" -> where(q, [t], ilike(field(t, ^column), ^value))
              end

            [column, "in", values] ->
              {column, values} = cast_column_values(table_schema, column, values)
              where(q, [t], field(t, ^column) in ^values)

            [column, "is", value] ->
              # TODO unknown
              case value do
                "null" -> where(q, [t], is_nil(field(t, ^column)))
                "true" -> where(q, [t], field(t, ^column) == true)
                "false" -> where(q, [t], field(t, ^column) == false)
              end
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

  defp cast_column_value(table_schema, column, value) do
    column_type = Map.fetch!(table_schema, column)
    {String.to_atom(column), cast_column_value(value, column_type)}
  end

  defp cast_column_values(table_schema, column, values) do
    column_type = Map.fetch!(table_schema, column)
    values = parse_values(values)
    {String.to_atom(column), Enum.map(values, &cast_column_value(&1, column_type))}
  end

  defp cast_column_value(value, :integer), do: String.to_integer(value)
  defp cast_column_value(value, :real), do: String.to_float(value)
  defp cast_column_value(value, :text), do: value
  defp cast_column_value(value, :blob), do: value

  defp parse_values("(" <> rest) do
  end
end
