defmodule Cartex do
  @moduledoc """
  Documentation for `Cartex`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Cartex.hello()
      :world

  """
  def hello do
    :world
  end

  # @spec make_trivial_handlers_query(integer, list, list, integer, integer, integer) :: Map
  def make_trivial_handlers_query(n, offsets, names, _, tail, distance) do
    for {{name, offset}, i} <- Enum.with_index(Enum.zip(names, offsets), 1) do
      case i do
        ^n -> %{offset: nil, limit: tail, name: name} |> query_to_string # "limit #{tail}"
        _ -> 
          cond do
            n - i > distance -> %{offset: offset, limit: 1, name: name} |> query_to_string # "offset #{offset} limit 1"
            n - i < distance -> %{offset: nil, limit: 1, name: name} |> query_to_string # "limit 1"
            true -> %{offset: offset + 1, limit: 1, name: name} |> query_to_string # "offset #{offset} + 1 limit 1"
          end
      end
    end 
    |> join_queries
  end

  # @spec make_trivial_handlers(integer, list, list, integer, integer, integer) :: Map
  def make_trivial_handlers(n, offsets, names, head, tail, distance) when n - distance > 1 do
    # ["if(", Enum.at(offsets, n - distance - 1), " + 1 < n"] ++ make_trivial_handlers_query(n, offsets, names, head, tail, distance) ++ ["else"] ++ make_trivial_handlers(n, offsets, names, head, tail, distance + 1)
    "if(?offset_#{n - distance} + 1 < n, #{make_trivial_handlers_query(n, offsets, names, head, tail, distance)}, #{make_trivial_handlers(n, offsets, names, head, tail, distance + 1)})"
  end

  # @spec make_trivial_handlers(integer, list, list, integer, integer, integer) :: Map
  def make_trivial_handlers(n, offsets, names, head, tail, distance) do
    make_trivial_handlers_query(n, offsets, names, head, tail, distance)
  end

  # @spec make_trivial_handlers(integer, list, list, integer, integer) :: Map
  def make_trivial_handlers(n, offsets, names, head, tail) do
    first_query = for {{name, offset}, i} <- Enum.with_index(Stream.zip(names, offsets), 1) do
      case i do
        ^n -> %{offset: nil, limit: head, name: name} |> query_to_string
        _ -> %{offset: offset, limit: 1, name: name} |> query_to_string
      end
    end
    |> join_queries

    second_query = make_trivial_handlers(n, offsets, names, head, tail, 1)

    %{first_query: first_query, second_query: second_query}
  end

  # @spec query_to_string(Map) :: String.t
  def query_to_string(%{offset: offset, limit: limit, name: name}) do
    case %{offset: offset, limit: limit} do
      %{offset: nil, limit: nil} -> "select (?relation as ?#{name}) { include %relations } "
      %{offset: offset, limit: nil} -> "select (?relation as ?#{name}) { include %relations } offset #{offset}"
      %{offset: nil, limit: limit} -> "select (?relation as ?#{name}) { include %relations } limit #{limit}"
      %{offset: offset, limit: limit} -> "select (?relation as ?#{name}) { include %relations } offset #{offset} limit #{limit}"
    end
  end

  def join_queries(queries, sep \\ " ") do
    for query <- queries do
      "{ #{query} }"
    end
    |> Enum.join(sep)
  end
end

