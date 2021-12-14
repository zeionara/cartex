defmodule CliMacros do
  defmacro parse_integer(min: min, description: description) do
    quote do
      fn(n) ->
        case Integer.parse(n) do
          :error -> {:error, "Invalid #{unquote(description)} - cannot interpret provided value as an integer"}
          {n, _} -> cond do
            n < unquote(min) -> {:error, "Please provide a higher #{unquote(description)} (at least this parameter must be equal to #{unquote(min)})"}
            true -> {:ok, n}
          end
        end
      end
    end
  end
end

defmodule Cartex do
  require CliMacros
  import CliMacros

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

  def main(argv) do
    Optimus.new!(
      name: "cartex",
      description: "SPARQL query optimizer which allows to split complex queries based on iterating over cartesian products of graph component sets",
      version: "0.17",
      author: "Zeio Nara zeionara@gmail.com",
      about: "The tool is intended to be used in applications heavy relying on knowledge base data sources or which implement some algorithms of data structure analysis. The tool allows to broaden the range of datasets which may be explored automatically using popular knowledge base engines.",
      allow_unknown_args: false,
      parse_double_dash: true,
      subcommands: [
        make_meta_query: [
          name: "make-meta-query",
          about: "Generate SPARQL query which can be used for generating a query for processing a subset of cartesian product entries",
          options: [
            offset: [
              value_name: "OFFSET",
              help: "Number of elements which should be skipped during processing a batch of cartesian product entries",
              required: false,
              parser: parse_integer(min: 0, description: "number of skipped items"), # :integer,
              default: "{{offset}}",
              short: "-s",
              long: "--offset"
            ],
            limit: [
              value_name: "LIMIT",
              help: "Number of elements which should be processed during generated queries execution",
              required: false,
              parser: parse_integer(min: 1, description: "batch size"), # :integer,
              default: "{{offset}}",
              short: "-b",
              long: "--limit"
            ],
            n: [
              value_name: "n",
              help: "Number of times the self-join operation should be performed on the target collection to provide the main query with all required data combinations",
              required: true,
              parser: parse_integer(min: 2, description: "number of self-join operations"),
              # parser: fn(n) ->
              #   case Integer.parse(n) do
              #     :error -> {:error, "Invalid number of self-join operations - cannot interpret provided value as an integer"}
              #     {n, _} -> cond do
              #       n < 2 -> {:error, "At least 2 self-join operations must be executed, please provide a higher number of self-joins"}
              #       true -> {:ok, n}
              #     end
              #   end
              # end,
              short: "-n"
            ],
            kind: [
              value_name: "kind",
              help: "Type of query which should be generated",
              required: false,
              parser: fn(kind) ->
                String.to_atom(kind) |> case do
                  :negative_composition -> {:ok, kind}
                  _ -> {:error, "Cannot interpreted provided label of query kind: #{kind}"}
                end
              end,
              short: "-k",
              long: "--kind",
              default: :negative_composition
            ]
          ]
        ]
      ]
      ) |> Optimus.parse!(argv) |> case do
        {[:make_meta_query], args} -> make_meta_query args
        {[command], _} -> raise "Unknown command #{command}"
      end
  end

  def make_meta_query(%Optimus.ParseResult{options: %{limit: limit, offset: offset, n: n}}) do
    """
    select ?query {
      {
        select (count(distinct ?relation) as ?n_relations) where {
          [] ?relation []
        }
      }

      bind(#{offset} as ?offset_0)
      bind(#{limit} as ?limit_0)

      #{Cartex.split_offset(n)}

      #{Cartex.split_limit(n)}

      bind(
        if(
          ?limit_0 >= ?n_relations,
          concat("ERROR: Batch size must be less than ", str(?n_relations)),
          if(
            ?offset_0 >= #{for _ <- 1..n do "?n_relations" end |> Enum.join(" * ")},
            concat("ERROR: Stop iteration when generating query with offset ", str(?offset_0)),
            #{Cartex.make_trivial_handlers(n, ["premise", "statement", "conclusion"], 17, 3)}
          )
        ) as ?query
      )
    }
    """ |> IO.puts # TODO: Eliminate redundant arguments from the make_trivial_handlers call above
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
    "if(?offset_#{n - distance} + 1 < ?n_relations, #{make_trivial_handlers_query(n, names, head, tail, distance)}, #{make_trivial_handlers(n, names, head, tail, distance + 1)})"
  end

  # @spec make_trivial_handlers(integer, list, list, integer, integer, integer) :: Map
  def make_trivial_handlers(n, names, head, tail, distance) do
    make_trivial_handlers_query(n, names, head, tail, distance)
  end

  # @spec make_trivial_handlers(integer, list, list, integer, integer) :: Map
  def make_trivial_handlers(n, names, head, tail) do
    prefix = "select (count(*) as ?count) ?premise ?statement ?conclusion with { select distinct ?relation where { [] ?relation [] } order by ?relation } as %relations with { select ?premise ?statement ?conclusion { "
    suffix = " } as %relations_ where { include %relations_  ?h ?premise ?t. ?t ?statement ?n. filter(!exists{?h ?conclusion ?n}) } group by ?premise ?statement ?conclusion order by desc(?count)"

    first_query = for {name, i} <- Enum.with_index(names, 1) do
      case i do
        ^n -> %{offset: i, limit: n, name: name} |> query_to_string()
        _ -> %{offset: i, limit: 1, name: name} |> query_to_string(is_numerical_limit: true)
      end
    end
    |> join_queries

    second_query = make_trivial_handlers(n, names, head, tail, 1)

    """
    concat("#{prefix}", #{join_queries([first_query, second_query], ", \" union \" ,")}, " } ", "#{suffix}")
    """ |> String.replace("\n", "")
    # %{first_query: first_query, second_query: second_query}
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

  # def head_limit_to_limit(head_limit) do
  #   "limit_#{head_limit}_1"
  # end

  # def tail_limit_to_limit(tail_limit) do
  #   "limit_#{tail_limit}_2"
  # end

  # def limit_number_to_limit(limit_number, is_tail_limit \\ false) do
  #   case is_tail_limit do
  #     false -> head_limit_to_limit(limit_number)
  #     true -> tail_limit_to_limit(limit_number)
  #   end
  # end

  # @spec query_to_string(Map) :: String.t
  def query_to_string(%{offset: offset_number, limit: limit, name: name}, opts \\ []) do
    is_numerical_offset = Keyword.get(opts, :is_numerical_offset, false)
    is_numerical_limit = Keyword.get(opts, :is_numerical_limit, false)
    is_tail_limit = Keyword.get(opts, :is_tail_limit, false)

    limit_kind = if is_tail_limit, do: :tail, else: :head

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

  def join_queries(queries, sep \\ ", ") do
    for query <- queries do
      """
      " { ", #{query}, " } "
      """ |> String.replace("\n", "")
    end
    |> Enum.join(sep)
  end

  def make_mod(dividend, divisor, result, opts \\ []) do
    quotient = Keyword.get(opts, :quotient, "#{result}_quotient")

    """
    bind(floor(?#{dividend} / ?#{divisor}) as ?#{quotient}) 
    bind(?#{dividend} - ?#{quotient} * ?#{divisor} as ?#{result})
    """ |> String.replace("\n", "")
  end

  def split_offset(n) do
    # """
    # bind(floor(?#{offset_number_to_offset(0)} / ?n_relations) as ?#{offset_number_to_offset(n)}_remainder)
    # """
    
    for i <- n..2 do
      """
      #{
        make_mod(
          (
            if i == n, do: offset_number_to_offset(0), else: "#{offset_number_to_offset(i + 1)}_quotient"
          ),
          "n_relations",
          offset_number_to_offset(i),
          quotient: (
            if i > 2, do: "#{offset_number_to_offset(i)}_quotient", else: offset_number_to_offset(i - 1)
          )
        )
      }
      """ |> String.replace("\n", "")
    end |> Enum.join(" ")
  end

  def split_limit(n) do
    for i <- n..2 do
      root_divisor_name = (
        if i == n, do: limit_number_to_limit(0, kind: :root), else: "#{limit_number_to_limit(i + 1, kind: :root)}_quotient"
      )
      """
      #{
        make_mod(
          root_divisor_name,
          "n_relations",
          "#{limit_number_to_limit(i, kind: :root)}_max",
          quotient: "#{limit_number_to_limit(i, kind: :root)}_min_quotient"
        )
      } 
      bind(?n_relations - ?#{offset_number_to_offset(i)} as ?n_relations_sub_#{offset_number_to_offset(i)}) 
      bind(if (?#{limit_number_to_limit(i, kind: :root)}_min_quotient > 0 || ?n_relations_sub_#{offset_number_to_offset(i)} < ?#{limit_number_to_limit(i, kind: :root)}_max, 
        ?n_relations_sub_#{offset_number_to_offset(i)}, ?#{limit_number_to_limit(i, kind: :root)}_max) as ?#{limit_number_to_limit(i)}) 
      bind(?#{root_divisor_name} - ?#{limit_number_to_limit(i)} as ?#{root_divisor_name}_updated) 
      #{
        make_mod(
          "#{root_divisor_name}_updated",
          "n_relations",
          "#{limit_number_to_limit(i, kind: :tail)}",
          quotient: (if i > 2, do: "#{limit_number_to_limit((i), kind: :root)}_quotient", else: limit_number_to_limit((i - 1), kind: :root))
        )
      }
      bind(?#{limit_number_to_limit(i)} + ?#{limit_number_to_limit(i, kind: :tail)} as ?#{limit_number_to_limit(i, kind: :root)})
      """ |> String.replace("\n", "")
    end |> Enum.join(" ")
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
end

