defmodule Cartex.Blazegraph.Converters do
  @cell_length 10

  defp join(row) do
    row
    |> Stream.map(
      fn(cell) ->
        String.pad_trailing(cell, @cell_length - 1)
      end
    )
    |> Enum.join(" | ")
  end

  def as_table(result) do
    vars = result["head"]["vars"]

    IO.puts vars |> join
    IO.puts (for _ <- 1..(length(vars) * @cell_length + length(vars) - 1) do "-" end |> Enum.join)
    IO.puts (
      for binding <- result["results"]["bindings"] do
        for var <- vars do
          binding[var]["value"]
        end
        |> join
      end
      |> Enum.join("\n")
    )
  end

  def as_metaquery_execution_result(result) do
    hd(result["results"]["bindings"])["query"]["value"]
  end
end
