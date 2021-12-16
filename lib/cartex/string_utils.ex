defmodule Cartex.StringUtils do
  @indentation_step Application.get_env(:cartex, :indentation_step)

  def indentation_step, do: @indentation_step

  def make_indentation(length, step \\ @indentation_step) do
    for _ <- 1..(length * step) do " " end |> Enum.join
  end

  def offset_number_to_offset(offset_number) do
    "offset_#{offset_number}"
  end

  def limit_number_to_limit(limit_number, opts \\ []) do
    kind = Keyword.get(opts, :kind, :head)
    "limit_#{limit_number}" <> case kind do
      :head -> "_1"
      :tail -> "_2"
      :root -> ""
    end
  end

  def query_to_string([{:offset, offset}, {:limit, limit}, {:name, name} | _]) do
    is_numerical_offset = if offset == nil, do: nil, else: Keyword.get(offset, :raw, false)
    is_numerical_limit = if limit == nil, do: nil, else: Keyword.get(limit, :raw, false)
    limit_kind = if limit == nil, do: nil, else: Keyword.get(limit, :kind, :head)

    offset_suffix = if offset == nil, do: nil, else: Keyword.get(offset, :suffix, "")
    limit_suffix = if limit == nil, do: nil, else: Keyword.get(limit, :suffix, "")

    offset_value = if offset == nil, do: nil, else: Keyword.get(offset, :value, nil)
    limit_value = if limit == nil, do: nil, else: Keyword.get(limit, :value, nil)

    case %{offset: offset_value, limit: limit_value} do
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
            "select (?relation as ?#{name}) { include %relations } limit ", str(?#{limit_number_to_limit(limit, kind: limit_kind)}#{limit_suffix})
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
                "select (?relation as ?#{name}) { include %relations } offset #{offset} limit ", str(?#{limit_number_to_limit(limit, kind: limit_kind)} #{limit_suffix})
                """ |> String.replace("\n", "")
              true -> """
                "select (?relation as ?#{name}) { include %relations } offset ", str(?#{offset_number_to_offset(offset)}#{offset_suffix}), " limit ", str(?#{limit_number_to_limit(limit, kind: limit_kind)}#{limit_suffix})
                """ |> String.replace("\n", "")
            end
        end
    end
  end

  def join_queries(queries, sep \\ ", ", indentation_length \\ 0) do
    indentation = make_indentation(indentation_length)

    for query <- queries do
      stringified_query = """
      " { ",\\n#{query},\\n#{indentation}" } "
      """ |> String.replace("\n", "")
      
      stringified_query
    end
    |> Enum.join(sep)
  end

  def batcher_to_string(batcher, indentation_length \\ 1) do
    current_indentation = make_indentation(indentation_length)
    nested_indentation = make_indentation(indentation_length + 1)

    case batcher do
      [:if, condition, positive_clause, negative_clause] ->
          "#{current_indentation}" <> 
            "if(\\n#{nested_indentation}#{condition}," <>
            "\\n#{nested_indentation}concat(\\n#{batcher_to_string(positive_clause, indentation_length + 2)}\\n#{nested_indentation})," <>
            case negative_clause do
              [head | _] -> (
                if head == :if,
                  do: "\\n#{batcher_to_string(negative_clause, indentation_length + 1)}",
                  else: "\\n#{nested_indentation}concat(\\n#{batcher_to_string(negative_clause, indentation_length + 2)}\\n#{nested_indentation})"  
                )
              :no_query -> " \"\"" 
            end <>
            "\\n#{current_indentation})"
      [padding: padding, increment: increment] ->
          "#{batcher_to_string(padding, indentation_length)},\\n#{current_indentation}\" union \",\\n#{batcher_to_string(increment, indentation_length)}"
      [[[{:offset, _}, {:limit, _}  | _ ] | _ ] | _] = queries ->
          stringified_queries = 
            queries
            |> Enum.map(
              fn(query) ->
                batcher_to_string(query, indentation_length + 1)
              end
            )
            |> join_queries(",\\n#{current_indentation}\" union \",\\n#{current_indentation}", indentation_length)

          "#{current_indentation}#{stringified_queries}"
      [[{:offset, _}, {:limit, _}  | _ ] | _] = queries ->
          stringified_queries =
            queries
            |> Enum.map(
              fn(query) ->
                batcher_to_string(query, indentation_length + 1)
              end
            )
            |> join_queries(",\\n#{current_indentation}", indentation_length)

          "#{current_indentation}#{stringified_queries}"
      [{:offset, _}, {:limit, _}  | _ ] = query ->
          "#{current_indentation}#{query_to_string(query)}"

      _ -> "#{current_indentation}cannot parse batcher"
    end
  end
end

