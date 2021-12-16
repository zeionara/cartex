defmodule Cartex.IndexHandlers do
  import Cartex.StringUtils

  def make_mod(dividend, divisor, result, opts \\ []) do
    quotient = Keyword.get(opts, :quotient, "#{result}_quotient")
    indentation_length = Keyword.get(opts, :indentation_length, 0)

    indentation = make_indentation(indentation_length)

    """
    #{indentation}bind(floor(?#{dividend} / ?#{divisor}) as ?#{quotient})\\n
    #{indentation}bind(?#{dividend} - ?#{quotient} * ?#{divisor} as ?#{result})\\n
    """ |> String.replace("\n", "")
  end

  def split_offset(n, indentation_length \\ 0) do
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
          ),
          indentation_length: indentation_length
        )
      }
      """ |> String.replace("\n", "")
    end |> Enum.join("\\n") |> String.replace("\\n", "\n")
  end

  def split_limit(n, indentation_length \\ 0) do
    indentation = make_indentation(indentation_length)

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
          quotient: "#{limit_number_to_limit(i, kind: :root)}_min_quotient",
          indentation_length: indentation_length
        )
      }

      #{indentation}bind(?n_relations - ?#{offset_number_to_offset(i)} #{if i < n, do: " - 1", else: ""} as ?n_relations_sub_#{offset_number_to_offset(i)})\\n

      #{indentation}bind(
      if (?#{limit_number_to_limit(i, kind: :root)}_min_quotient > 0 || ?n_relations_sub_#{offset_number_to_offset(i)} < ?#{limit_number_to_limit(i, kind: :root)}_max,
      ?n_relations_sub_#{offset_number_to_offset(i)},
      ?#{limit_number_to_limit(i, kind: :root)}_max) as ?#{limit_number_to_limit(i)})\\n\\n

      #{indentation}bind(?#{root_divisor_name} - ?#{limit_number_to_limit(i)} as ?#{root_divisor_name}_updated)\\n

      #{
        make_mod(
          "#{root_divisor_name}_updated",
          "n_relations",
          "#{limit_number_to_limit(i, kind: :tail)}",
          quotient: (if i > 2, do: "#{limit_number_to_limit((i), kind: :root)}_quotient", else: limit_number_to_limit((i - 1), kind: :root)),
          indentation_length: indentation_length
        )
      }

      #{indentation}bind(?#{limit_number_to_limit(i)} + ?#{limit_number_to_limit(i, kind: :tail)} as ?#{limit_number_to_limit(i, kind: :root)})\\n
      """ |> String.replace("\n", "")
    end |> Enum.join("\\n") |> String.replace("\\n", "\n")
  end
end

