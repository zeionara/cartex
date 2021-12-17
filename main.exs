n = 3
offset = 16
limit = 8
core = "?h ?premise ?t. ?t ?statement ?n. filter(!exists{?h ?conclusion ?n})"
verbose_header = false
output = nil
names = ["premise", "statement", "conclusion"]

blazegraph_host = "172.16.55.163"

query = Cartex.Cli.make_meta_query(
  %Optimus.ParseResult{options: %{limit: limit, offset: offset, n: n, core: core, output: output}, flags: %{verbose_header: verbose_header, silent: true}, unknown: names}
)

HTTPoison.start
case HTTPoison.post(
  "http://#{blazegraph_host}:9999/bigdata/namespace/kb/sparql",
  # "query=select+(count(*)+as+%3Fcount)+%7B+%3Fh+%3Fr+%3Ft+%7D%0D%0A",
  # "select+(count(*)+as+%3Fcount)+%7B+%3Fh+%3Fr+%3Ft+%7D%0D%0A"
  # URITools.encode_www_form("select (count(*) as ?count) { ?h ?r ?t }\r\n", ["(", ")", "*"]),
  # "query=#{URITools.encode_www_form("select (count(*) as ?count) ?h { ?h ?r ?t } group by ?h limit 5", ["(", ")", "*"])}",
  # "query=#{URITools.encode_www_form("select (count(*) as ?count) { ?h ?r ?t }", ["(", ")", "*"])}",
  "query=#{URITools.encode_www_form(query, ["(", ")", "*"])}",
  [{"Accept", "application/sparql-results+json"}, {"Content-Type", "application/x-www-form-urlencoded; charset=UTF-8"}]
) do
  {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> Jason.decode!(body) |> Cartex.BlazegraphConverters.as_table
end

# Cartex.make_all_handlers(4, ["foo", "bar", "baz", "qux"], "<<core>>") |> IO.inspect
# Cartex.make_all_handlers(4, ["foo", "bar", "baz", "qux"], "<<core>>", as_string: true) |> IO.puts
# Cartex.make_all_handlers(3, ["foo", "bar", "baz"], "<<core>>") |> IO.inspect
