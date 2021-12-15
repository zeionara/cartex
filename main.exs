# n = 3
# offset = 16
# limit = 8
# 
# query = """
# # select #{Cartex.make_verbose_header(3)} {
# select ?query {
#   {
#     select (count(distinct ?relation) as ?n_relations) where {
#       [] ?relation []
#     }
#   }
# 
#   bind(#{offset} as ?offset_0)
#   bind(#{limit} as ?limit_0)
# 
#   #{Cartex.split_offset(n)}
#  
#   #{Cartex.split_limit(n)}
# 
#   #{"bind(#{Cartex.make_trivial_handlers(n, ["premise", "statement", "conclusion"], 17, 3)} as ?query)"}
# }
# """ |> IO.puts

# Cartex.make_all_handlers(4, ["foo", "bar", "baz", "qux"], "<<core>>") |> IO.inspect
# Cartex.make_all_handlers(4, ["foo", "bar", "baz", "qux"], "<<core>>", as_string: true) |> IO.puts
Cartex.make_all_handlers(3, ["foo", "bar", "baz"], "<<core>>") |> IO.inspect
