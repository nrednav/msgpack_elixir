defmodule Bench.Decode do
  def run do
    IO.puts("\n--- Benchmarking Msgpack.decode!/2 ---")

    encoded_inputs = Bench.Encode.prepare_decode_inputs()

    Benchee.run(
      %{
        "Decode" => fn encoded_binary ->
          Msgpack.decode!(encoded_binary)
        end
      },
      inputs: encoded_inputs,
      time: 5,
      memory_time: 2,
      warmup: 2,
      formatters: [Benchee.Formatters.Console]
    )
  end
end

Bench.Decode.run()
