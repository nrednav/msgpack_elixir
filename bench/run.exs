Mix.Task.run("compile")

IO.puts("--- Running MessagePack Benchmark Suite ---")
IO.puts("Loading benchmark files...")

bench_path = __DIR__

Path.join(bench_path, "encode_bench.exs") |> Code.require_file()
Path.join(bench_path, "decode_bench.exs") |> Code.require_file()
Path.join(bench_path, "string_validation_bench.exs") |> Code.require_file()
