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
          ],
          flags: [
            verbose_header: [
              long: "--verbose-header",
              help: "Include additional information into the generated query header",
              miltiple: false
            ],
            silent: [
              long: "--silent",
              help: "Do not output the generated query",
              miltiple: false
            ]
          ]
        ]
      ]
      ) |> Optimus.parse!(argv) |> case do
        {[:make_meta_query], args} -> make_meta_query args
        {[command], _} -> raise "Unknown command #{command}"
      end
  end

  def make_meta_query(%Optimus.ParseResult{options: %{limit: limit, offset: offset, n: n, core: core, output: output}, flags: %{verbose_header: verbose_header, silent: silent}, unknown: names}) do
    n_entries = for _ <- 1..n do "?n_relations" end |> Enum.join(" * ")

    query = """
    select #{if verbose_header, do: Cartex.make_verbose_header(n) <> " ", else: ""}?query {
      {
        select (count(distinct ?relation) as ?n_relations) where {
          [] ?relation []
        }
      }

      bind(#{offset} as ?offset_0)
      bind(#{limit} as ?limit_0)

      bind(#{n_entries} as ?n_entries)

      # offset

    #{Cartex.IndexHandlers.split_offset(n, 1)}
      # limit
     
    #{Cartex.IndexHandlers.split_limit(n, 1)}
      bind(
        if(
          ?limit_0 >= ?n_entries,
          concat("ERROR: Batch size must be less than ", str(?n_entries)),
          if(
            ?offset_0 >= ?n_entries,
            concat("ERROR: Stop iteration when generating query with offset ", str(?offset_0)),
    #{Cartex.make_all_handlers(n, (if length(names) < 1, do: ["premise", "statement", "conclusion"], else: names), core)}
          )
        )
        as ?query
      )
    }
    """

    case output do
      nil -> unless silent do IO.puts(query) end
      _ -> case File.open(output, [:write]) do
        {:ok, file} -> 
          IO.binwrite(file, query)
          File.close(file)
        {:error, error} -> raise "Cannot open file #{output} for writing: #{error}"
      end
    end

    query
  end

  def make_specific_query(
    %Optimus.ParseResult{options: %{limit: limit, offset: offset, core: core, output: output}, flags: %{silent: silent}, unknown: names}
  ) do
    list_of_names_in_select_header = for name <- names do "?#{name}" end
    joined_list_of_names_in_select_header = list_of_names_in_select_header |> Enum.join(" ")

    query = """
    select (count(*) as ?count) #{joined_list_of_names_in_select_header}
    with {
      select distinct ?relation where {
        [] ?relation []
      } order by ?relation
    } as %relations
    with {
      select #{joined_list_of_names_in_select_header} {
        #{
          for {name, i} <- Stream.with_index(list_of_names_in_select_header) do
          """
          #{if i > 0, do: "    ", else: ""}{
                select (?relation as #{name}) {
                  include %relations  
                }
              }
          """ 
          end
        }<<<no-newline
      }
      order by #{joined_list_of_names_in_select_header}
      offset #{offset}
      limit #{limit}
    } as %relations_
    where {
      include %relations_
      #{core}
    }
    group by #{joined_list_of_names_in_select_header}
    order by desc(?count)
    """ |> String.replace("\n<<<no-newline", "")

    case output do
      nil -> unless silent do IO.puts(query) end
      _ -> case File.open(output, [:write]) do
        {:ok, file} -> 
          IO.binwrite(file, query)
          File.close(file)
        {:error, error} -> raise "Cannot open file #{output} for writing: #{error}"
      end
    end

    query
  end
end

