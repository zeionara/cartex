# Cartex

SPARQL query optimizer which allows to split complex queries based on iterating over cartesian products of graph component sets.

The tool is intended to be used in applications heavy relying on knowledge base data sources or which implement some algorithms of data structure analysis. The tool allows to broaden the range of datasets which may be explored automatically using popular knowledge base engines.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `cartex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cartex, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/cartex](https://hexdocs.pm/cartex).

## Building an executable script

To build a self-sufficient package which may be launched as an executable script, execute the following commands from the root folder of the cloned repo:

```sh
mix deps.get
mix escript.build
```

## Usage

The only way to use the application is via its command-line interface. Currently only generation of metaqueries is supported, which can be initiated with the following call:

```sh
./cartex make-meta-query -n 3 foo bar baz -c '?h ?foo ?t. ?t ?bar ?n. filter(!exists{?h ?baz ?n})' -s 16 -b 8 -o foo.txt
```

The generated metaquery is being written to the `foo.txt` file, but in case `-o` option would have been omitted, the query would be written directly to the console.

For more information about the app please, use appropriate `help` options:

```sh
./cartex --help
./cartex help make-meta-query
```

