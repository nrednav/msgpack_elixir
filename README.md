# msgpack_elixir

[![Hex.pm](https://img.shields.io/hexpm/v/msgpack_elixir.svg)](https://hex.pm/packages/msgpack_elixir)

A [MessagePack](https://msgpack.org/) serialization library for Elixir.

## Features

- **Full Specification Compliance:** Adheres to the MessagePack specification to
  ensure compatibility with other MessagePack implementations
  - Includes support for types such as `Booleans`, `Integers`, `Floats`, `Tuples`,
    `Lists`, `Maps`, `Strings`, `Binaries`, `Extensions`, and `Timestamps`
  - Encodes and decodes Elixir's `DateTime` and `NaiveDateTime` structs using
    the MessagePack `Timestamp` extension
- **Performant Encoding:** Implements efficient encoding for collections and
  provides a `:string_validation` option to bypass UTF-8 validation in
  performance-sensitive applications
- **Exception-raising Variants:** Includes bang (`!`) variants like `encode!/2`
  and `decode!/2` for contexts where raising an exception is preferred over
  error tuples
- **Telemetry Integration:** Emits standard `:telemetry` events for all encode
  and decode operations, allowing for easy integration into monitoring and
  observability tools

## Installation

Add `msgpack_elixir` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:msgpack_elixir, "~> 1.0.0"}]
end
```

Then, run `mix deps.get`.

## Usage

### Basic Operations

The library returns `{:ok, value}` tuples for successful operations and
`{:error, reason}` tuples for failures.

```elixir
# Encode a map
iex> data = %{"id" => 1, "name" => "Elixir"}
iex> {:ok, encoded} = Msgpack.encode(data)
<<130, 162, 105, 100, 1, 164, 110, 97, 109, 101, 166, 69, 108, 105, 120, 105, 114>>

# Decode a binary
iex> Msgpack.decode(encoded)
{:ok, %{"id" => 1, "name" => "Elixir"}}
```

### Exception-raising Operations

If you prefer an exception to be raised on failure, use the bang (`!`) variants.

```elixir
iex> encoded = Msgpack.encode!(%{id: 1})
<<129, 162, 105, 100, 1>>

iex> Msgpack.decode!(<<192, 42>>)
** (Msgpack.DecodeError) Failed to decode MessagePack binary. Reason = {:trailing_bytes, <<42>>}
```

## Options

The following options can be passed as a second argument to the `encode` and
`decode` functions.

### For `encode/2`

- `:atoms`
  - Controls how atoms are encoded.
  - `:string` (default) - Encodes atoms as MessagePack strings
  - `:error` - Returns an `{:error, {:unsupported_atom, atom}}` tuple if an atom
    is encountered
- `:string_validation`
  - Controls whether to perform UTF-8 validation on binaries
  - `true` (default) - Validates binaries; encodes as `str` type if valid UTF-8,
    `bin` type otherwise
  - `false` - Skips validation and encodes all binaries as the `str` type.
    Improves performance but should only be used if you are certain your data is
    valid

### For `decode/2`

- `:max_depth`
  - Sets a limit on the nesting level of arrays and maps to prevent stack
    exhaustion attacks
  - Defaults to `100`
- `:max_byte_size`
  - Sets a limit on the declared byte size of any single string, binary, array,
    or map to prevent memory exhaustion attacks
  - Defaults to `10_000_000` (10MB)

## Telemetry

The library emits `:telemetry` events which can be used for monitoring or
logging.

- `[:msgpack, :encode]` - Dispatched when `Msgpack.encode/2` is called
- `[:msgpack, :decode]` - Dispatched when `Msgpack.decode/2` is called

Example of attaching a logger:

```elixir
defmodule MyTelemetryHandler do
  require Logger

  def attach do
    :telemetry.attach(
      "msgpack-logger",
      [:msgpack, :encode],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event(event_name, measurements, metadata, _config) do
    Logger.info("Telemetry Event: #{inspect(event_name)}",
      measurements: measurements,
      metadata: metadata
    )
  end
end
```

## Development

This section explains how to setup the project locally for development.

### Dependencies

- Elixir `~> 1.7` (OTP 21+)

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
