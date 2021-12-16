defmodule Cartex.CliMacros do
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

defmodule Cartex.Cli do
  require Cartex.CliMacros

  import Cartex.CliMacros
  import Cartex.IndexHandlers

  def main(argv) do
    Optimus.new!(
      name: "cartex",
      description: "SPARQL query optimizer which allows to split complex queries based on iterating over cartesian products of graph component sets",
      version: "0.17",
      author: "Zeio Nara zeionara@gmail.com",
      about: "The tool is intended to be used in applications heavy relying on knowledge base data sources or which implement some algorithms of data structure analysis. The tool allows to broaden the range of datasets which may be explored automatically using popular knowledge base engines.",
      parse_double_dash: true,
      subcommands: [
        make_meta_query: [
          name: "make-meta-query",
          about: "Generate SPARQL query which can be used for generating a query for processing a subset of cartesian product entries",
          allow_unknown_args: true,
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
              default: "{{limit}}",
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
            ],
            core: [
              value_name: "CORE",
              help: "The main part of the query without auxiliary structures",
              required: false,
              parser: :string,
              default: "?h ?premise ?t. ?t ?statement ?n. filter(!exists{?h ?conclusion ?n})",
              short: "-c",
              long: "--core"
            ],
            output: [
              value_name: "OUTPUT",
              help: "Path to local file for writing the generated query",
              required: false,
              parser: :string,
              short: "-o",
              long: "--output"
            ]
          ]
        ]
      ]
      ) |> Optimus.parse!(argv) |> case do
        {[:make_meta_query], args} -> make_meta_query args
        {[command], _} -> raise "Unknown command #{command}"
      end
  end

  def make_meta_query(%Optimus.ParseResult{options: %{limit: limit, offset: offset, n: n, core: core, output: output}, unknown: names}) do
    query = """
    select ?query {
      {
        select (count(distinct ?relation) as ?n_relations) where {
          [] ?relation []
        }
      }

      bind(#{offset} as ?offset_0)
      bind(#{limit} as ?limit_0)

      # offset

    #{Cartex.IndexHandlers.split_offset(n, 2)}
      # limit
     
    #{Cartex.IndexHandlers.split_limit(n, 2)}
      bind(
        if(
          ?limit_0 >= ?n_relations,
          concat("ERROR: Batch size must be less than ", str(?n_relations)),
          if(
            ?offset_0 >= #{for _ <- 1..n do "?n_relations" end |> Enum.join(" * ")},
            concat("ERROR: Stop iteration when generating query with offset ", str(?offset_0)),
    #{Cartex.make_all_handlers(n, (if length(names) < 1, do: ["premise", "statement", "conclusion"], else: names), core)}
          )
        )
        as ?query
      )
    }
    """

    case output do
      nil -> IO.puts(query)
      _ -> case File.open(output, [:write]) do
        {:ok, file} -> 
          IO.binwrite(file, query)
          File.close(file)
        {:error, error} -> raise "Cannot open file #{output} for writing: #{error}"
      end
    end
  end
end

