defmodule Cartex.StringUtils do
  def offset_number_to_offset(offset_number) do
    "offset_#{offset_number}"
  end

  def limit_number_to_limit(limit_number, opts \\ []) do
    kind = Keyword.get(opts, :kind, :head)
    "limit_#{limit_number}" <> case kind do
      :head -> "_1"
      :tail -> "_2"
      :root -> ""
    end
  end

  # @spec query_to_string(Map) :: String.t
  def query_to_string(%{offset: offset_number, limit: limit, name: name}, opts \\ []) do
    is_numerical_offset = Keyword.get(opts, :is_numerical_offset, false)
    is_numerical_limit = Keyword.get(opts, :is_numerical_limit, false)
    is_tail_limit = Keyword.get(opts, :is_tail_limit, false)

    limit_kind = if is_tail_limit, do: :tail, else: :head

    offset_suffix = Keyword.get(opts, :offset_suffix, "")
    limit_suffix = Keyword.get(opts, :limit_suffix, "")

    case %{offset: offset_number, limit: limit} do
      %{offset: nil, limit: nil} -> """
        "select (?relation as ?#{name}) { include %relations }"
      """ |> String.replace("\n", "")
      %{offset: offset, limit: nil} ->
        cond do
          is_numerical_offset -> """
            "select (?relation as ?#{name}) { include %relations } offset #{offset}"
            """ |> String.replace("\n", "")
          true -> """
            "select (?relation as ?#{name}) { include %relations } offset", str(?#{offset_number_to_offset(offset)}#{offset_suffix})
            """ |> String.replace("\n", "")
        end
      %{offset: nil, limit: limit} ->
        cond do
          is_numerical_limit -> """
            "select (?relation as ?#{name}) { include %relations } limit #{limit}"
            """ |> String.replace("\n", "")
          true -> """
            "select (?relation as ?#{name}) { include %relations } limit ", str(?#{limit_number_to_limit(limit, kind: limit_kind)}#{limit_suffix})
            """ |> String.replace("\n", "")
        end
      %{offset: offset, limit: limit} -> 
        cond do
          is_numerical_limit -> 
            cond do 
              is_numerical_offset -> """
                "select (?relation as ?#{name}) { include %relations } offset #{offset} limit #{limit}"
                """ |> String.replace("\n", "")
              true -> """
                "select (?relation as ?#{name}) { include %relations } offset ", str(?#{offset_number_to_offset(offset)}#{offset_suffix}), " limit #{limit}"
                """ |> String.replace("\n", "")
            end
          true ->
            cond do
              is_numerical_offset -> """
                "select (?relation as ?#{name}) { include %relations } offset #{offset} limit ", str(?#{limit_number_to_limit(limit, kind: limit_kind)} #{limit_suffix})
                """ |> String.replace("\n", "")
              true -> """
                "select (?relation as ?#{name}) { include %relations } offset ", str(?#{offset_number_to_offset(offset)}#{offset_suffix}), " limit ", str(?#{limit_number_to_limit(limit, kind: limit_kind)}#{limit_suffix})
                """ |> String.replace("\n", "")
            end
        end
    end
  end

  def join_queries(queries, sep \\ ", ") do
    for query <- queries do
      """
      " { ", #{query}, " } "
      """ |> String.replace("\n", "")
    end
    |> Enum.join(sep)
  end
end

