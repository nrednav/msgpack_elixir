defmodule Bench.Encode do
  @inputs %{
    "Small Map" => %{
      "id" => 123,
      "name" => "Msgpack Elixir",
      "is_awesome" => true,
      "version" => 1.0
    },
    "Large List" => Enum.to_list(1..1000),
    "Large Map" => Map.new(1..1000, &{&1, &1 * 2}),
    "Nested Data" => %{
      "user_id" => 456,
      "data" => [
        %{
          "event" => "login",
          "timestamp" => NaiveDateTime.utc_now(),
          "details" => %{"ip" => "127.0.0.1"}
        }
      ]
    },
    "Large Binary" => %{
      "key" => "data",
      "payload" => :crypto.strong_rand_bytes(10_000)
    }
  }

  def run do
    IO.puts("\n--- Benchmarking Msgpack.encode!/2 ---")

    Benchee.run(
      %{
        "Encode (Default)" => fn input ->
          Msgpack.encode!(input)
        end,
        "Encode (Optimized)" => fn input ->
          Msgpack.encode!(input, string_validation: false)
        end
      },
      inputs: @inputs,
      time: 5,
      memory_time: 2,
      warmup: 2,
      formatters: [Benchee.Formatters.Console]
    )
  end

  def prepare_decode_inputs do
    for {name, term} <- @inputs, into: %{} do
      {name, Msgpack.encode!(term)}
    end
  end
end

Bench.Encode.run()
