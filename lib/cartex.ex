defmodule Cartex do
  import Cartex.StringUtils

  # @spec make_trivial_handlers_query(integer, list, list, integer, integer, integer) :: Map
  def make_trivial_handlers_query(n, names, distance) do
    # joined_queries = for {name, i} <- Enum.with_index(names, 1) do
    #   case i do
    #     ^n -> %{offset: nil, limit: i, name: name} |> query_to_string(is_tail_limit: true) # "limit #{tail}"
    #     _ -> 
    #       cond do
    #         n - i > distance -> %{offset: i, limit: 1, name: name} |> query_to_string(is_numerical_limit: true) # "offset #{offset} limit 1"
    #         n - i < distance -> %{offset: nil, limit: 1, name: name} |> query_to_string(is_numerical_limit: true) # "limit 1"
    #         true -> %{offset: i, limit: 1, name: name} |> query_to_string(is_numerical_limit: true, offset_suffix: " + 1") # "offset #{offset} + 1 limit 1"
    #       end
    #   end
    # end 
    # |> join_queries

    # "concat(#{joined_queries})"
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

    # first_query = for {name, i} <- Enum.with_index(names, 1) do
    #   case i do
    #     ^n -> %{offset: i, limit: n, name: name} |> query_to_string()
    #     _ -> nil # %{offset: i, limit: 1, name: name} |> query_to_string(is_numerical_limit: true)
    #   end
    # end
    # |> join_queries

    # second_query = make_trivial_handlers(n, names, 1)

    # """
    # concat("#{prefix}", #{join_queries([first_query, second_query], ", \" union \" ,")}, " } ", "#{suffix}")
    # """ |> String.replace("\n", "")
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

  def flatten_one_dimension(list) do
    case list do
      [] -> []
      [head | tail] -> head ++ flatten_one_dimension(tail)
    end
  end

  def check_next_query_pair(pairs, _found_pair) when pairs == [] do
    pairs
  end

  def check_next_query_pair(pairs, found_pair) do
    [{subquery, next} | tail] = pairs

    case {subquery, next} do
      {[offset: nil, limit: [value: limit_value, kind: :tail], name: subquery_name], [offset: nil, limit: nil, name: next_name]} ->
        # IO.inspect {subquery, next}
        [
          [offset: [value: "#{limit_number_to_limit(limit_value, kind: :tail)}", raw: true], limit: [value: 1, raw: true], name: subquery_name],
          [offset: nil, limit: [value: limit_value + 1, kind: :tail], name: next_name]
        ] ++ check_next_query_pair(tail, true)
      _ -> case found_pair do
        false ->
          case subquery do
            nil -> check_next_query_pair(tail, found_pair)
            _ -> [subquery] ++ check_next_query_pair(tail, found_pair)
          end
        true -> 
          case next do
            nil -> check_next_query_pair(tail, found_pair)
            _ -> [next] ++ check_next_query_pair(tail, found_pair)
          end
      end
    end
  end

  def make_subsequent_query(base) do
    # pairs = for {subquery, next} <- Enum.zip([nil | base], base) do
    #   case {subquery, next} do
    #     {[offset: nil, limit: [value: limit_value, kind: :tail], name: subquery_name], [offset: nil, limit: nil, name: next_name]} ->
    #       # IO.inspect {subquery, next}
    #       {
    #         [offset: [value: "#{limit_number_to_limit(limit_value, kind: :tail)}", raw: true], limit: [value: 1, raw: true], name: subquery_name],
    #         [offset: nil, limit: [value: limit_value + 1, kind: :tail], name: next_name]
    #       }
    #     _ -> {subquery, next} # IO.inspect {subquery, next}
    #   end
    # end

    check_next_query_pair(Enum.zip([nil | base], base ++ [nil]), false)

    # flattened_pairs = pairs |> Enum.map(&Tuple.to_list/1) |> flatten_one_dimension |> List.delete_at(0)
    # [_ | tail] = flattened_pairs

    # for {lhs, rhs} <- Enum.zip(flattened_pairs, tail ++ [nil]) do
    #   case {lhs, rhs} do
    #     {last_item, nil} -> [last_item]
    #     _ ->
    #       cond do
    #         lhs == rhs -> [lhs]
    #         true -> [lhs, rhs]
    #       end
    #   end
    # end |> IO.inspect
  end

  def make_subsequent_queries(query) do
    subsequent_query = make_subsequent_query(query)

    cond do
      subsequent_query == query -> [] 
      true -> 
        # IO.puts "One subsequent query"
        # IO.inspect subsequent_query
        
        [subsequent_query | make_subsequent_queries(subsequent_query)]
    end
  end

  def make_incremental_query(n, m, k, names) do
    query = for {name, i} <- Enum.with_index(names, 1) do
      cond do
        i < n - m && i > n - k -> [offset: nil, limit: [value: 1, raw: true], name: name]
        i == n - m -> [offset: nil, limit: [value: i, kind: :tail], name: name]
        i == n - k -> [offset: [value: i, suffix: " + 1"], limit: [value: 1, raw: true], name: name]
        i > n - m -> [offset: nil, limit: nil, name: name]
        true -> [offset: [value: i], limit: [value: 1, raw: true], name: name] # (if i == 1, do: [value: i, kind: :root], else: [value: i])
      end
    end

    # IO.puts "Incremental query (n - m = #{n - m})"
    # IO.inspect query

    # IO.puts "Subsequent queries"
    # make_subsequent_queries(query) |> IO.inspect

    [query | make_subsequent_queries(query)]
  end

  def make_increment(n, m, k, names) when n - k > 1 do
    [
      :if,
      "?#{offset_number_to_offset(n - k)} + 1 < ?n_relations",
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
            struct = [offset: [value: i], limit: [value: i], name: name]
            struct
          _ ->
            struct = [offset: [value: i], limit: [value: 1, raw: true], name: name]
            struct
        end
      end
    ]

    result = cond do
      m > 0 ->
      result ++ for k <- 1..m do 
        query = for {name, i} <- Enum.with_index(names, 1) do
          cond do
            i == n - k -> [offset: [value: i, suffix: " + 1"], limit: (if i == 1, do: [value: i, kind: :root], else: [value: i]), name: name] # |> query_to_string(offset_suffix: " + 1")
            i > n - k -> [offset: nil, limit: nil, name: name] # |> query_to_string(is_numerical_limit: true)
            true -> [offset: [value: i], limit: [value: 1, raw: true], name: name] # |> query_to_string(is_numerical_limit: true)
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

    root_incremental_query = for {name, i} <- Enum.with_index(names, 1) do
      cond do
        i == n - m -> [offset: [value: i, suffix: " + ?#{limit_number_to_limit(i, kind: (if i == 1, do: :root, else: :head))} + 1"], limit: [value: 1, raw: true], name: name] # + limit_number_to_limit(n - m) + 1
        i == n - m + 1 -> [offset: nil, limit: [value: i, kind: :tail], name: name]
        i > n - m + 1 -> [offset: nil, limit: nil, name: name]
        true -> [offset: [value: i], limit: [value: i], name: name]
      end
    end

    root_incremental_query_with_subsequent_queries = [root_incremental_query | make_subsequent_queries(root_incremental_query)]

    increment = cond do
      m == 0 -> make_increment(n, m, m + 1, names)
      m == n - 1 -> root_incremental_query_with_subsequent_queries
      true -> [
      :if,
        "?#{offset_number_to_offset(n - m)} + ?#{limit_number_to_limit(n - m)} + 1 < ?n_relations",
        root_incremental_query_with_subsequent_queries,
        make_increment(n, m, m + 1, names)
      ]
    end

    [padding: result, increment: increment]
  end

  def make_next_handler(n, names, m \\ 0) when m < n - 1 do
    # IO.puts "MAKE NEXT HANDLER for m = #{m}, n = #{n}"
    [
      :if,
      for k <- (m + 1)..(n - 1) do "?#{limit_number_to_limit(n - k, kind: :root)} = 0" end |> Enum.join(" && "),
      make_handlers_for_m(n, m, names),
      make_next_handler(n, names, m + 1)
    ]
  end

  def make_next_handler(n, names, m) do
    # IO.puts "MAKE NEXT UNCONDITIONED HANDLER for m = #{m}, n = #{n}"
     make_handlers_for_m(n, m, names)
  end

  def make_all_handlers(n, names, core, _opts \\ []) do
    # result = []

    # result = for m <- 0..(n-1) do
    #   [
    #     {
    #       String.to_atom("m_#{m}"),
    #       make_handlers_for_m(n, m, names)
    #     }
    #   | result ]
    # end

    # result
    batcher = make_next_handler(n, names)

    # batcher_to_string(batcher) |> IO.puts

    # batcher

    list_of_names_in_select_header = for name <- names do "?#{name}" end |> Enum.join(" ")
    prefix = "select (count(*) as ?count) #{list_of_names_in_select_header} " <> 
      "with { select distinct ?relation where { [] ?relation [] } order by ?relation } as %relations with { select #{list_of_names_in_select_header} { "
    suffix = " } as %relations_ where { include %relations_  #{core} } group by #{list_of_names_in_select_header} order by desc(?count)"

#     prefix = """
# select (count(*) as ?count) #{list_of_names_in_select_header} 
# with {
#   select distinct ?relation where { [] ?relation [] } order by ?relation
# } as %relations
# with {
#   select #{list_of_names_in_select_header} {
# #{batcher_to_string(batcher, 4, 4)}
#   }
# }
# """ |> IO.puts

#     batcher
# "#{prefix}",\\n
#"#{suffix}"\\n
    """
        concat(\\n
          "select (count(*) as ?count) #{list_of_names_in_select_header} ",\\n
          "with {",\\n
            "select distinct ?relation where {",\\n
              "[] ?relation []",\\n
            "} order by ?relation",\\n
          "} as %relations ",\\n
          "with {",\\n
            "select #{list_of_names_in_select_header} {",\\n
#{batcher_to_string(batcher, 10, 10)},\\n
            " } ",\\n
          " } as %relations_ ",\\n
          "where {",\\n
            "include %relations_",\\n
            "#{core}",\\n
          "} group by #{list_of_names_in_select_header} ",\\n
          "order by desc(?count)"\\n
        )
    """ |> String.replace("\n", "") |> String.replace("\\n", "\n")
  end
end

