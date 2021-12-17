defmodule Cartex do
  import Cartex.StringUtils

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

  def check_next_query_pair(pairs, found_pair, collected_queries \\ [])

  def check_next_query_pair(pairs, _found_pair, collected_queries) when pairs == [] do
    collected_queries
  end

  def check_next_query_pair(pairs, found_pair, collected_queries) do
    [{subquery, next} | tail] = pairs

    check_next_query_pair(
      tail,
      true,
      collected_queries ++ 
        case {subquery, next} do
          {[offset: nil, limit: [value: limit_value, kind: :tail], name: subquery_name], [offset: nil, limit: nil, name: next_name]} ->
            [
              [offset: [value: "\", str(?#{limit_number_to_limit(limit_value, kind: :tail)}), \"", raw: true], limit: [value: 1, raw: true], name: subquery_name],
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
    )
  end

  def make_subsequent_query(base) do
    check_next_query_pair(Enum.zip([nil | base], base ++ [nil]), false)
  end

  def make_subsequent_queries(query) do
    subsequent_query = make_subsequent_query(query)

    cond do
      subsequent_query == query -> [] 
      true -> 
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
        true -> [offset: [value: i], limit: [value: 1, raw: true], name: name]
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
  
  def make_next_handler(n, names, m \\ 0)

  def make_next_handler(n, names, m) when m < n - 1 do
    [
      :if,
      for k <- (m + 1)..(n - 1) do "?#{limit_number_to_limit(n - k, kind: :root)} = 0" end |> Enum.join(" && "),
      make_handlers_for_m(n, m, names),
      make_next_handler(n, names, m + 1)
    ]
  end

  def make_next_handler(n, names, m) do
     make_handlers_for_m(n, m, names)
  end

  def make_all_handlers(n, names, core, _opts \\ []) do
    batcher = make_next_handler(n, names)
    list_of_names_in_select_header = for name <- names do "?#{name}" end |> Enum.join(" ")

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
#{batcher_to_string(batcher, 7)},\\n
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

