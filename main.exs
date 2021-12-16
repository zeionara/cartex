n = 3
offset = 16
limit = 8

"""
# select #{Cartex.make_verbose_header(3)} {
select ?query {
  {
    select (count(distinct ?relation) as ?n_relations) where {
      [] ?relation []
    }
  }

  bind(#{offset} as ?offset_0)
  bind(#{limit} as ?limit_0)

  # offset

#{Cartex.IndexHandlers.split_offset(n, 1)}
  # limit
 
#{Cartex.IndexHandlers.split_limit(n, 1)}
  bind(
#{Cartex.make_all_handlers(n, ["premise", "statement", "conclusion"], "?h ?premise ?t. ?t ?statement ?n. filter(!exists{?h ?conclusion ?n})")}
    as ?query
  )
}
""" |> IO.puts

# Cartex.make_all_handlers(4, ["foo", "bar", "baz", "qux"], "<<core>>") |> IO.inspect
# Cartex.make_all_handlers(4, ["foo", "bar", "baz", "qux"], "<<core>>", as_string: true) |> IO.puts
# Cartex.make_all_handlers(3, ["foo", "bar", "baz"], "<<core>>") |> IO.inspect
