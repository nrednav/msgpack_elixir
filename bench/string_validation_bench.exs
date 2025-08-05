defmodule Bench.StringValidation do
  @large_string String.duplicate("a", 10_000)

  def run do
    IO.puts("==== Benchmarking String Validation ====")
    IO.puts("Compares default encoding vs. encoding with string_validation: false")

    Benchee.run(
      %{
        "Default (with validation)" => fn ->
          Msgpack.encode!(@large_string, string_validation: true)
        end,
        "Fast Path (without validation)" => fn ->
          Msgpack.encode!(@large_string, string_validation: false)
        end,
      },
      time: 5,
      memory_time: 2
    )
  end
end

Bench.StringValidation.run()
