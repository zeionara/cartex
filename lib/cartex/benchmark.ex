defmodule Cartex.Benchmark do
  @execution_time_accuracy 6
  def measure_execution_time(function) do
    function
    |> :timer.tc
    |> elem(0)
    |> Kernel./(1_000_000)
  end

  def print_execution_time(function) do
    measure_execution_time(function)
    |> (&(IO.puts "Executed in " <> :erlang.float_to_binary(&1, decimals: @execution_time_accuracy) <> " seconds")).()
  end
end

