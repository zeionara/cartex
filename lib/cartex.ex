defmodule Cartex do
  import Cartex.StringUtils

  # @spec make_trivial_handlers_query(integer, list, list, integer, integer, integer) :: Map
  def make_trivial_handlers_query(n, names, distance) do
    joined_queries = for {name, i} <- Enum.with_index(names, 1) do
      case i do
        ^n -> %{offset: nil, limit: i, name: name} |> query_to_string(is_tail_limit: true) # "limit #{tail}"
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
  def make_trivial_handlers(n, names, distance) when n - distance > 1 do
    "if(?offset_#{n - distance} + 1 < ?n_relations, #{make_trivial_handlers_query(n, names, distance)}, #{make_trivial_handlers(n, names, distance + 1)})"
  end

  # @spec make_trivial_handlers(integer, list, list, integer, integer, integer) :: Map
  def make_trivial_handlers(n, names, distance) do
    make_trivial_handlers_query(n, names, distance)
  end

  # @spec make_trivial_handlers(integer, list, list, integer, integer) :: Map
  def make_handlers(n, names, core) do
    list_of_names_in_select_header = for name <- names do "?#{name}" end |> Enum.join(" ")

    prefix = "select (count(*) as ?count) #{list_of_names_in_select_header} " <> 
      "with { select distinct ?relation where { [] ?relation [] } order by ?relation } as %relations with { select #{list_of_names_in_select_header} { "
    suffix = " } as %relations_ where { include %relations_  #{core} } group by #{list_of_names_in_select_header} order by desc(?count)"

    first_query = for {name, i} <- Enum.with_index(names, 1) do
      case i do
        ^n -> %{offset: i, limit: n, name: name} |> query_to_string()
        _ -> %{offset: i, limit: 1, name: name} |> query_to_string(is_numerical_limit: true)
      end
    end
    |> join_queries

    second_query = make_trivial_handlers(n, names, 1)

    """
    concat("#{prefix}", #{join_queries([first_query, second_query], ", \" union \" ,")}, " } ", "#{suffix}")
    """ |> String.replace("\n", "")
    # %{first_query: first_query, second_query: second_query}
  end

  def make_verbose_header(n) do
    for i <- 1..n do
      "?#{offset_number_to_offset(i)}"
    end
    ++
    for i <- 1..n do
      "?#{limit_number_to_limit(i, kind: :head)} ?#{limit_number_to_limit(i, kind: :tail)} ?#{limit_number_to_limit(i, kind: :root)}"
    end    
    |> Enum.join(" ")
  end

  def make_incremental_query(n, m, k, names) do
    for {name, i} <- Enum.with_index(names, 1) do
      cond do
        # i == n - m - 1 -> %{offset: i, limit: 1, name: name} # + 1
        i < n - m && i > n - k -> %{offset: nil, limit: 1, name: name}
        i == n - m -> %{offset: nil, limit: i, name: name} # tail limit
        i == n - k -> %{offset: i, limit: 1, name: name} # + 1
        i > n - m -> %{offset: nil, limit: nil, name: name}
        true -> %{offset: i, limit: i, name: name}
      end
    end
  end

  def make_increment(n, m, k, names) when n - k > 1 do
    # [
    #   :if,
    #   "#{offset_number_to_offset(n - m - 1)} + 1 < ?n_relations",
    #   for {name, i} <- Enum.with_index(names, 1) do
    #     cond do
    #       i == n - m - 1 -> %{offset: i, limit: 1, name: name} # + 1
    #       i == n - m -> %{offset: nil, limit: i, name: name} # tail limit
    #       i > n - m -> %{offset: nil, limit: nil, name: name}
    #       true -> %{offset: i, limit: i, name: name}
    #     end
    #   end
    # ]
    [
      :if,
      "#{offset_number_to_offset(k)} + 1 < ?n_relations",
      make_incremental_query(n, m, k, names),
      make_increment(n, m, k + 1, names)
    ]
  end

  def make_increment(n, m, k, names) do
    make_incremental_query(n, m, k, names)
  end

  def make_handlers_for_m(n, m, names) do
    result = [
      for {name, i} <- Enum.with_index(names, 1) do
        case i do
          ^n ->
            struct = %{offset: i, limit: i, name: name}
            struct
            # %{struct: struct, string: query_to_string(struct)} 
          _ ->
            struct = %{offset: i, limit: 1, name: name}
            struct
            # %{struct: struct, string: query_to_string(struct, is_numerical_limit: true)}
        end
      end
    ]

    result = cond do
      m > 0 ->
      result ++ for k <- 1..m do 
        query = for {name, i} <- Enum.with_index(names, 1) do
          cond do
            i == n - k -> %{offset: i, limit: i, name: name} # |> query_to_string(offset_suffix: " + 1")
            i > n - k -> %{offset: nil, limit: nil, name: name} # |> query_to_string(is_numerical_limit: true)
            true -> %{offset: i, limit: 1, name: name} # |> query_to_string(is_numerical_limit: true)
          end
        end

        case k do
          ^m -> query
          _ -> [
            :if,
            "?#{offset_number_to_offset(n - k)} + 1 < ?n_relations",
            query,
            :no_query
          ]
        end
      end
      true -> result
    end

    increment = [
      :if,
      "#{offset_number_to_offset(n - m)} + #{limit_number_to_limit(n - m)} + 1 < ?n_relations",
      for {name, i} <- Enum.with_index(names, 1) do
        cond do
          i == n - m -> %{offset: i, limit: 1, name: name} # + limit_number_to_limit(n - m) + 1
          i == n - m + 1 -> %{offset: nil, limit: i, name: name}
          i > n - m + 1 -> %{offset: nil, limit: nil, name: name}
          true -> %{offset: i, limit: i, name: name}
        end
      end,
      make_increment(n, m, m + 1, names)
      # [
      #   :if,
      #   "#{offset_number_to_offset(n - m - 1)} + 1 < ?n_relations",
      #   for {name, i} <- Enum.with_index(names, 1) do
      #     cond do
      #       i == n - m - 1 -> %{offset: i, limit: 1, name: name} # + 1
      #       i == n - m -> %{offset: nil, limit: i, name: name} # tail limit
      #       i > n - m -> %{offset: nil, limit: nil, name: name}
      #       true -> %{offset: i, limit: i, name: name}
      #     end
      #   end
      # ]
    ]

    [padding: result, increment: increment]
  end

  def make_all_handlers(n, names, _core, opts \\ []) do
    # as_string = Keyword.get(opts, :as_string, false)

    result = []

    result = for m <- 0..(n-1) do
      [
        {
          String.to_atom("m_#{m}"),
          make_handlers_for_m(n, m, names)
        }
      | result ]
    end

    result
    # case as_string do
    #   true -> last_digit_queries |> Enum.map(fn(query) -> query.string end) |> join_queries
    #   _ -> last_digit_queries |> Enum.map(fn(query) -> query.struct end)
    # end
  end
end

