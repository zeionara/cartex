defmodule Cartex.IndexHandlers do
  import Cartex.StringUtils

  def make_mod(dividend, divisor, result, opts \\ []) do
    quotient = Keyword.get(opts, :quotient, "#{result}_quotient")

    """
    bind(floor(?#{dividend} / ?#{divisor}) as ?#{quotient}) 
    bind(?#{dividend} - ?#{quotient} * ?#{divisor} as ?#{result})
    """ |> String.replace("\n", "")
  end

  def split_offset(n) do
    for i <- n..2 do
      """
      #{
        make_mod(
          (
            if i == n, do: offset_number_to_offset(0), else: "#{offset_number_to_offset(i + 1)}_quotient"
          ),
          "n_relations",
          offset_number_to_offset(i),
          quotient: (
            if i > 2, do: "#{offset_number_to_offset(i)}_quotient", else: offset_number_to_offset(i - 1)
          )
        )
      }
      """ |> String.replace("\n", "")
    end |> Enum.join(" ")
  end

  def split_limit(n) do
    for i <- n..2 do
      root_divisor_name = (
        if i == n, do: limit_number_to_limit(0, kind: :root), else: "#{limit_number_to_limit(i + 1, kind: :root)}_quotient"
      )
      """
      #{
        make_mod(
          root_divisor_name,
          "n_relations",
          "#{limit_number_to_limit(i, kind: :root)}_max",
          quotient: "#{limit_number_to_limit(i, kind: :root)}_min_quotient"
        )
      } 
      bind(?n_relations - ?#{offset_number_to_offset(i)} #{if i < n, do: " - 1", else: ""} as ?n_relations_sub_#{offset_number_to_offset(i)}) 
      bind(if (?#{limit_number_to_limit(i, kind: :root)}_min_quotient > 0 || ?n_relations_sub_#{offset_number_to_offset(i)} < ?#{limit_number_to_limit(i, kind: :root)}_max, 
        ?n_relations_sub_#{offset_number_to_offset(i)}, ?#{limit_number_to_limit(i, kind: :root)}_max) as ?#{limit_number_to_limit(i)}) 
      bind(?#{root_divisor_name} - ?#{limit_number_to_limit(i)} as ?#{root_divisor_name}_updated) 
      #{
        make_mod(
          "#{root_divisor_name}_updated",
          "n_relations",
          "#{limit_number_to_limit(i, kind: :tail)}",
          quotient: (if i > 2, do: "#{limit_number_to_limit((i), kind: :root)}_quotient", else: limit_number_to_limit((i - 1), kind: :root))
        )
      }
      bind(?#{limit_number_to_limit(i)} + ?#{limit_number_to_limit(i, kind: :tail)} as ?#{limit_number_to_limit(i, kind: :root)})
      """ |> String.replace("\n", "")
    end |> Enum.join(" ")
  end
end

