defmodule Cartex.ListUtils do
  def flatten_one_dimension(list) do
    case list do
      [] -> []
      [head | tail] -> head ++ flatten_one_dimension(tail)
    end
  end
end

