n = 3
offset = 1000
limit = 8
core = "?h ?premise ?t. ?t ?statement ?n. filter(!exists{?h ?conclusion ?n})"
verbose_header = false
output = nil
names = ["premise", "statement", "conclusion"]

Cartex.Blazegraph.Client.start

Cartex.Benchmark.print_execution_time(
  fn() ->
    Cartex.Cli.make_meta_query(
      %Optimus.ParseResult{options: %{limit: limit, offset: offset, n: n, core: core, output: output}, flags: %{verbose_header: verbose_header, silent: true}, unknown: names}
    )
    |> Cartex.Blazegraph.Client.run
    |> case do
      {:ok, response} ->
        response # Cartex.Blazegraph.Converters.as_table response
        |> Cartex.Blazegraph.Converters.as_metaquery_execution_result
        |> Cartex.Blazegraph.Client.run
        |> case do
          {:ok, response} ->
            response
            |> Cartex.Blazegraph.Converters.as_table
          {_, error} ->
            IO.puts "Error executing specific query"
            IO.inspect error
        end
      {_, error} ->
        IO.puts "Error executing metaquery"
        IO.inspect error
    end
  end
)

IO.puts ""

Cartex.Benchmark.print_execution_time(
  fn() ->
    Cartex.Cli.make_specific_query(
      %Optimus.ParseResult{options: %{limit: limit, offset: offset, core: core, output: output}, flags: %{silent: true}, unknown: names}
    )
    |> Cartex.Blazegraph.Client.run
    |> case do
      {:ok, response} ->
        response
        |> Cartex.Blazegraph.Converters.as_table
      {_, error} ->
        IO.puts "Error executing specific query"
        IO.inspect error
    end
  end
)

# Cartex.make_all_handlers(4, ["foo", "bar", "baz", "qux"], "<<core>>") |> IO.inspect
# Cartex.make_all_handlers(4, ["foo", "bar", "baz", "qux"], "<<core>>", as_string: true) |> IO.puts
# Cartex.make_all_handlers(3, ["foo", "bar", "baz"], "<<core>>") |> IO.inspect
