n = 3
offset = 16
limit = 8
core = "?h ?premise ?t. ?t ?statement ?n. filter(!exists{?h ?conclusion ?n})"
verbose_header = false
output = nil
names = ["premise", "statement", "conclusion"]

Cartex.Cli.make_meta_query(
  %Optimus.ParseResult{options: %{limit: limit, offset: offset, n: n, core: core, output: output}, flags: %{verbose_header: verbose_header}, unknown: names}
)

# Cartex.make_all_handlers(4, ["foo", "bar", "baz", "qux"], "<<core>>") |> IO.inspect
# Cartex.make_all_handlers(4, ["foo", "bar", "baz", "qux"], "<<core>>", as_string: true) |> IO.puts
# Cartex.make_all_handlers(3, ["foo", "bar", "baz"], "<<core>>") |> IO.inspect
