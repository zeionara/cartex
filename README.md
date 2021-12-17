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

## Benchmarks

Although the tools allows to execute queries on graphs with huge number of relations which make in-place cartesian product calculation infeasible, it slows down query execution on smaller graphs. It is possible to perform your own evaluation via following call:

```sh
mix run main.ex
``` 

Before running the command make sure that file `config/config.exs` contains an actual ip-address of the running blazegraph server. The provided script produces log which allows to compare outputs from two-stage and one-stage query executions respectively:

```sh
count     | premise   | statement | conclusion
-------------------------------------------
35        | https://relentness.nara.zeio/wordnet-11/_subordinate_instance_of | https://relentness.nara.zeio/wordnet-11/_has_part | https://relentness.nara.zeio/wordnet-11/_part_of
35        | https://relentness.nara.zeio/wordnet-11/_subordinate_instance_of | https://relentness.nara.zeio/wordnet-11/_has_part | https://relentness.nara.zeio/wordnet-11/_domain_region
35        | https://relentness.nara.zeio/wordnet-11/_subordinate_instance_of | https://relentness.nara.zeio/wordnet-11/_has_part | https://relentness.nara.zeio/wordnet-11/_domain_topic
35        | https://relentness.nara.zeio/wordnet-11/_subordinate_instance_of | https://relentness.nara.zeio/wordnet-11/_has_part | https://relentness.nara.zeio/wordnet-11/_has_instance
35        | https://relentness.nara.zeio/wordnet-11/_subordinate_instance_of | https://relentness.nara.zeio/wordnet-11/_has_part | https://relentness.nara.zeio/wordnet-11/_has_part
35        | https://relentness.nara.zeio/wordnet-11/_subordinate_instance_of | https://relentness.nara.zeio/wordnet-11/_has_part | https://relentness.nara.zeio/wordnet-11/_member_holonym
35        | https://relentness.nara.zeio/wordnet-11/_subordinate_instance_of | https://relentness.nara.zeio/wordnet-11/_has_part | https://relentness.nara.zeio/wordnet-11/_member_meronym
29        | https://relentness.nara.zeio/wordnet-11/_subordinate_instance_of | https://relentness.nara.zeio/wordnet-11/_has_instance | https://relentness.nara.zeio/wordnet-11/_type_of
Executed in 0.304528 seconds

count     | premise   | statement | conclusion
-------------------------------------------
35        | https://relentness.nara.zeio/wordnet-11/_subordinate_instance_of | https://relentness.nara.zeio/wordnet-11/_has_part | https://relentness.nara.zeio/wordnet-11/_part_of
35        | https://relentness.nara.zeio/wordnet-11/_subordinate_instance_of | https://relentness.nara.zeio/wordnet-11/_has_part | https://relentness.nara.zeio/wordnet-11/_domain_region
35        | https://relentness.nara.zeio/wordnet-11/_subordinate_instance_of | https://relentness.nara.zeio/wordnet-11/_has_part | https://relentness.nara.zeio/wordnet-11/_domain_topic
35        | https://relentness.nara.zeio/wordnet-11/_subordinate_instance_of | https://relentness.nara.zeio/wordnet-11/_has_part | https://relentness.nara.zeio/wordnet-11/_has_instance
35        | https://relentness.nara.zeio/wordnet-11/_subordinate_instance_of | https://relentness.nara.zeio/wordnet-11/_has_part | https://relentness.nara.zeio/wordnet-11/_has_part
35        | https://relentness.nara.zeio/wordnet-11/_subordinate_instance_of | https://relentness.nara.zeio/wordnet-11/_has_part | https://relentness.nara.zeio/wordnet-11/_member_holonym
35        | https://relentness.nara.zeio/wordnet-11/_subordinate_instance_of | https://relentness.nara.zeio/wordnet-11/_has_part | https://relentness.nara.zeio/wordnet-11/_member_meronym
29        | https://relentness.nara.zeio/wordnet-11/_subordinate_instance_of | https://relentness.nara.zeio/wordnet-11/_has_instance | https://relentness.nara.zeio/wordnet-11/_type_of
Executed in 0.059215 seconds
```

So, in this case two-stage query execution strategy yields the same results, but executes 5x times slower than a simpler approach.

