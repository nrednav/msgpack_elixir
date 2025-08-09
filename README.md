# msgpack_elixir

[![Hex.pm](https://img.shields.io/hexpm/v/msgpack_elixir.svg)](https://hex.pm/packages/msgpack_elixir)

An implementation of the [MessagePack](https://msgpack.org/) serialization
format for Elixir.

It provides functions for encoding and decoding Elixir terms and supports the
full MessagePack specification, including the Timestamp and custom Extension
types.

## Features

- **Specification Compliance:** Implements the complete MessagePack type system.
- **Elixir Struct Support:** Encodes and decodes `DateTime` and `NaiveDateTime`
  structs via the Timestamp extension type.
- **Configurable Validation:** Provides an option to bypass UTF-8 validation on
  strings for performance-critical paths.
- **Resource Limiting:** Includes configurable `:max_depth` and `:max_byte_size`
  limits to mitigate resource exhaustion from malformed or malicious payloads.
- **Telemetry Integration:** Emits standard `:telemetry` events for integration
  with monitoring tools.
- **Streaming API:** Process large collections or continuous data streams with
  low memory overhead using `Msgpack.encode_stream/2` and
  `Msgpack.decode_stream/2`.

## Installation

Add `msgpack_elixir` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:msgpack_elixir, "~> 1.0.0"}]
end
```

Then, run `mix deps.get`.

## Quick Start

```elixir
# Encode a map. Atom keys are converted to strings by default.
iex> data = %{id: 1, name: "Elixir"}
iex> {:ok, encoded} = Msgpack.encode(data)
<<130, 162, 105, 100, 1, 164, 110, 97, 109, 101, 166, 69, 108, 105, 120, 105, 114>>

# Decode a binary.
iex> Msgpack.decode(encoded)
{:ok, %{"id" => 1, "name" => "Elixir"}}

# Use the exception-raising variants for exceptional failure cases.
iex> Msgpack.decode!(<<0xC1>>)
** (Msgpack.DecodeError) Unknown type prefix: 193. The byte `0xC1` is not a valid MessagePack type marker.
```

### Streaming Large Collections

For datasets that may not fit in memory, you can use the streaming API, which
processes one term at a time.

```elixir
# Create a lazy stream of terms to be encoded.
iex> terms = Stream.cycle([1, "elixir", true])

# The output is a lazy stream of encoded binaries.
iex> encoded_stream = Msgpack.encode_stream(terms)

# The stream is only consumed when you enumerate it.
iex> encoded_stream |> Stream.take(3) |> Enum.to_list()
[
  {:ok, <<1>>},
  {:ok, <<166, 101, 108, 105, 120, 105, 114>>},
  {:ok, <<195>>}
]
```

## Full Documentation

For detailed information on all features, options, and functions, see the [full
documentation on HexDocs](https://hexdocs.pm/msgpack_elixir/Msgpack.html), which
contains a complete API reference for all public modules and functions.

## Development

This section explains how to setup the project locally for development.

### Dependencies

- Elixir `~> 1.12` (OTP 24+)
  - See [Compatibility and
    deprecations](https://hexdocs.pm/elixir/1.18.4/compatibility-and-deprecations.html)
    for more information

### Get the Source

Clone the project locally:

```bash
# via HTTPS
git clone https://github.com/nrednav/msgpack_elixir.git

# via SSH
git clone git@github.com:nrednav/msgpack_elixir.git
```

### Install

Install the project's dependencies:

```bash
cd msgpack_elixir/
mix deps.get
```

### Test

Run the test suite:

```bash
mix test
```

### Benchmark

Run the benchmarks:

```bash
mix run bench/run.exs
```

## Versioning

This project uses [Semantic Versioning](https://semver.org/).
For a list of available versions, see the [repository tag list](https://github.com/nrednav/msgpack_elixir/tags).

## Issues & Requests

If you encounter a bug or have a feature request, please [open an
issue](https://github.com/nrednav/msgpack_elixir/issues) on the GitHub
repository.

## Contributing

Public contributions are welcome! If you would like to contribute, please fork
the repository and create a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE)
file for details.
