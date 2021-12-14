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
  def make_trivial_handlers_query(n, names, _, tail, distance) do
    joined_queries = for {name, i} <- Enum.with_index(names, 1) do
      case i do
        ^n -> %{offset: nil, limit: tail, name: name} |> query_to_string(is_tail_limit: true) # "limit #{tail}"
        _ -> 
          cond do
            n - i > distance -> %{offset: i, limit: 1, name: name} |> query_to_string(is_numerical_limit: true) # "offset #{offset} limit 1"
            n - i < distance -> %{offset: nil, limit: 1, name: name} |> query_to_string(is_numerical_limit: true) # "limit 1"
            true -> %{offset: i, limit: 1, name: name} |> query_to_string(is_numerical_limit: true, offset_suffix: " + 1") # "offset #{offset} + 1 limit 1"
          end
      end
    end 
    |> join_queries

    "concat(#{joined_queries})"
  end

  # @spec make_trivial_handlers(integer, list, list, integer, integer, integer) :: Map
  def make_trivial_handlers(n, names, head, tail, distance) when n - distance > 1 do
    # ["if(", Enum.at(offsets, n - distance - 1), " + 1 < n"] ++ make_trivial_handlers_query(n, offsets, names, head, tail, distance) ++ ["else"] ++ make_trivial_handlers(n, offsets, names, head, tail, distance + 1)
    "if(?offset_#{n - distance} + 1 < n, #{make_trivial_handlers_query(n, names, head, tail, distance)}, #{make_trivial_handlers(n, names, head, tail, distance + 1)})"
  end

  # @spec make_trivial_handlers(integer, list, list, integer, integer, integer) :: Map
  def make_trivial_handlers(n, names, head, tail, distance) do
    make_trivial_handlers_query(n, names, head, tail, distance)
  end

  # @spec make_trivial_handlers(integer, list, list, integer, integer) :: Map
  def make_trivial_handlers(n, names, head, tail) do
    prefix = "select (count(*) as ?count) ?premise ?statement ?conclusion with { select distinct ?relation where { [] ?relation [] } order by ?relation } as %relations with { select ?premise ?statement ?conclusion { "

    first_query = for {name, i} <- Enum.with_index(names, 1) do
      case i do
        ^n -> %{offset: nil, limit: head, name: name} |> query_to_string(is_numerical_limit: true)
        _ -> %{offset: i, limit: 1, name: name} |> query_to_string(is_numerical_limit: true)
      end
    end
    |> join_queries

    second_query = make_trivial_handlers(n, names, head, tail, 1)

    """
    concat("#{prefix}", #{join_queries([first_query, second_query], " union ")}, " } ")
    """ |> String.replace("\n", "")
    # %{first_query: first_query, second_query: second_query}
  end

  def offset_number_to_offset(offset_number) do
    "offset_#{offset_number}"
  end

  def head_limit_to_limit(head_limit) do
    "limit_#{head_limit}_1"
  end

  def tail_limit_to_limit(tail_limit) do
    "limit_#{tail_limit}_2"
  end

  def limit_number_to_limit(limit_number, is_tail_limit \\ false) do
    case is_tail_limit do
      false -> head_limit_to_limit(limit_number)
      true -> tail_limit_to_limit(limit_number)
    end
  end

  # @spec query_to_string(Map) :: String.t
  def query_to_string(%{offset: offset_number, limit: limit, name: name}, opts \\ []) do
    is_numerical_offset = Keyword.get(opts, :is_numerical_offset, false)
    is_numerical_limit = Keyword.get(opts, :is_numerical_limit, false)
    is_tail_limit = Keyword.get(opts, :is_tail_limit, false)

    offset_suffix = Keyword.get(opts, :offset_suffix, "")
    limit_suffix = Keyword.get(opts, :limit_suffix, "")

    case %{offset: offset_number, limit: limit} do
      %{offset: nil, limit: nil} -> """
        "select (?relation as ?#{name}) { include %relations }"
      """ |> String.replace("\n", "")
      %{offset: offset, limit: nil} ->
        cond do
          is_numerical_offset -> """
            "select (?relation as ?#{name}) { include %relations } offset #{offset}"
            """ |> String.replace("\n", "")
          true -> """
            "select (?relation as ?#{name}) { include %relations } offset", str(?#{offset_number_to_offset(offset)}#{offset_suffix})
            """ |> String.replace("\n", "")
        end
      %{offset: nil, limit: limit} ->
        cond do
          is_numerical_limit -> """
            "select (?relation as ?#{name}) { include %relations } limit #{limit}"
            """ |> String.replace("\n", "")
          true -> """
            "select (?relation as ?#{name}) { include %relations } limit", str(?#{limit_number_to_limit(limit, is_tail_limit)}#{limit_suffix})"
            """ |> String.replace("\n", "")
        end
      %{offset: offset, limit: limit} -> 
        cond do
          is_numerical_limit -> 
            cond do 
              is_numerical_offset -> """
                "select (?relation as ?#{name}) { include %relations } offset #{offset} limit #{limit}"
                """ |> String.replace("\n", "")
              true -> """
                "select (?relation as ?#{name}) { include %relations } offset ", str(?#{offset_number_to_offset(offset)}#{offset_suffix}), " limit #{limit}"
                """ |> String.replace("\n", "")
            end
          true ->
            cond do
              is_numerical_offset -> """
                "select (?relation as ?#{name}) { include %relations } offset #{offset} limit ", str(?#{limit_number_to_limit(limit, is_tail_limit)} #{limit_suffix})
                """ |> String.replace("\n", "")
              true -> """
                "select (?relation as ?#{name}) { include %relations } offset ", str(?#{offset_number_to_offset(offset)}#{offset_suffix}), " limit ", str(?#{limit_number_to_limit(limit, is_tail_limit)}#{limit_suffix})
                """ |> String.replace("\n", "")
            end
        end
    end
  end

  def join_queries(queries, sep \\ " ") do
    for query <- queries do
      """
      " { ", #{query} " } "
      """ |> String.replace("\n", "")
    end
    |> Enum.join(sep)
  end
end

