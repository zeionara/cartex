query = """
select ?query {
  {
    select (count(distinct ?relation) as ?n_relations) where {
      [] ?relation []
    }
  }

  bind(2 as ?offset_0)
  bind(2 as ?limit_0)

  #{Cartex.split_offset(4)}

  #{"bind(#{Cartex.make_trivial_handlers(4, ["foo", "bar", "baz", "qux"], 17, 3)} as ?query)"}
}
""" |> IO.puts
