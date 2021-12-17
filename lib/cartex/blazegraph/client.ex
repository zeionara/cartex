defmodule Cartex.Blazegraph.Client do
  @host Application.get_env(:cartex, :blazegraph)[:host]

  def start() do
    HTTPoison.start
  end

  def run(query) do
    case HTTPoison.post(
      "http://#{@host}:9999/bigdata/namespace/kb/sparql",
      "query=#{URITools.encode_www_form(query, ["(", ")", "*"])}",
      [
        {"Accept", "application/sparql-results+json"},
        {"Content-Type", "application/x-www-form-urlencoded; charset=UTF-8"}
      ]
    ) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> {:ok, Jason.decode!(body)}
      error -> error
    end
  end
end

