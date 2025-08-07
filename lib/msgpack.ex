defmodule Msgpack do
  @moduledoc """
  An implementation of the MessagePack serialization format.

  This module is the main entry point for the library, providing functions for
  encoding and decoding Elixir terms.

  ## Quick Start

  For the common case, you can encode an Elixir map or keyword list and decode
  it back. Note that by default, atoms used as map keys are encoded as strings.

  ```elixir
  iex> data = %{"id" => 1, "name" => "Elixir"}
  iex> {:ok, encoded} = Msgpack.encode(data)
  iex> Msgpack.decode(encoded)
  {:ok, %{"id" => 1, "name" => "Elixir"}}
  ```

  ## Capabilities

  - **Type Support:** Encodes and decodes common Elixir types, including
  integers, floats, binaries, lists, and maps.
  - **Timestamp Extension:** Automatically handles Elixir's `NaiveDateTime` and
  `DateTime` structs using the MessagePack Timestamp extension.
  - **Custom Extensions:** Provides `MessagePack.Ext` for working with custom
  MessagePack extension types.
  - **Resource Limits:** Includes options like `:max_depth` and `:max_byte_size`
  to limit resource allocation when decoding.
  - **Telemetry Integration:** Emits `:telemetry` events for monitoring and
  observability.

  ## Options

  The behaviour of `encode/2` and `decode/2` can be customized by passing a
  keyword list of options. See the documentation for each function for a full
  description.

  ### Common Encoding Options

  - `:atoms` - Controls how atoms are encoded (`:string` or `:error`).
  - `:string_validation` - Toggles UTF-8 validation for performance.

  ### Common Decoding Options

  - `:max_depth` - Limits the nesting level for decoding collections.
  - `:max_byte_size` - Limits the memory allocation for large objects.
  """

  alias Msgpack.Encoder
  alias Msgpack.Decoder
  alias Msgpack.StreamEncoder
  alias Msgpack.StreamDecoder
  alias Msgpack.EncodeError
  alias Msgpack.DecodeError

  @type error_reason ::
          # Encoding errors
          {:unsupported_type, term()}
          | {:unsupported_atom, atom()}
          # Decoding errors
          | :unexpected_eof
          | {:unknown_prefix, byte()}
          | {:trailing_bytes, binary()}
          | {:max_depth_reached, non_neg_integer()}
          | {:max_byte_size_exceeded, non_neg_integer()}
          | :invalid_timestamp

  @doc """
  Encodes an Elixir term into a MessagePack binary.

  Returns `{:ok, binary}` on success, or `{:error, reason}` on failure.

  ## Options

    * `:atoms` - Controls how atoms are encoded.
      * `:string` (default) - Encodes atoms as MessagePack strings.
      * `:error` - Returns an `{:error, {:unsupported_atom, atom}}` tuple if an atom is encountered.

    * `:string_validation` - Controls whether to perform UTF-8 validation on binaries.
      * `true` (default) - Validates binaries and encodes them as the `str` type
      if they are valid UTF-8, otherwise encodes them as the `bin` type. This
        ensures the output is compliant with the MessagePack specification's
        distinction between string and binary data, but has a performance cost.
      * `false` - Skips validation and encodes all binaries as the `str` type.
      This avoids the performance cost of validation but risks creating a
      payload with non-UTF-8 strings, which may be incompatible with other
      MessagePack decoders.

  ## Examples

  ### Standard Encoding

  The default options encode atoms as strings, a common requirement when sending
  data between Elixir services.

  ```elixir
  iex> data = %{id: 1, name: "Elixir"}
  iex> {:ok, encoded} = Msgpack.encode(data)
  iex> Msgpack.decode(encoded)
  {:ok, %{"id" => 1, "name" => "Elixir"}}
  ```

  ### Strict Atom Handling

  If you are interoperating with systems that do not have a concept of atoms, it
  is safer to disallow them completely during encoding.

  ```elixir
  iex> Msgpack.encode(%{name: "Elixir"}, atoms: :error)
  {:error, {:unsupported_atom, :name}}
  ```

  ### Encoding without String Validation (Unsafe)

  For performance-critical paths where you can guarantee all binaries are valid
  UTF-8 strings, you can disable string validation.

  ```elixir
  iex> data = "What did the fish say when it swam into a wall? Dam!"
  iex> {:ok, _} = Msgpack.encode(data, string_validation: false)
  ```

  ### Encoding Raw Binary Data

  If your data contains non-UTF-8 binary content (e.g., an image thumbnail), the
  default validator will encode it with the `bin` family type.

  ```elixir
  iex> Msgpack.encode(<<255, 128, 0>>)
  {:ok, <<0xC4, 3, 255, 128, 0>>}
  ```
  """
  @spec encode(term(), keyword()) :: {:ok, binary()} | {:error, error_reason()}
  def encode(term, opts \\ []) do
    :telemetry.span(
      [:msgpack, :encode],
      %{opts: opts, term: term},
      fn ->
        result = Encoder.encode(term, opts)

        case result do
          {:ok, iodata} ->
            binary = IO.iodata_to_binary(iodata)
            {{:ok, binary}, %{outcome: :ok, byte_size: byte_size(binary)}}

          {:error, reason} ->
            {{:error, reason}, %{outcome: :error}}
        end
      end
    )
  end

  @doc """
  Encodes an Elixir term into a MessagePack binary, raising an error on failure.

  This variant raises an exception on failure instead of returning an error
  tuple. It is intended for use in pipelines (`|>`) or in functions where an
  encoding failure is considered an exceptional event to be handled by
  `try/rescue`.

  ## Options

  Accepts the same options as `encode/2`.

  ## Raises

    * `Msgpack.EncodeError` - If an unsupported Elixir term is encountered.
    * `Msgpack.UnsupportedAtomError` - If an atom is encountered and the `:atoms` option is set to `:error`.

  ## Examples

  ```elixir
  iex> Msgpack.encode!(%{hello: "world"})
  <<129, 165, 104, 101, 108, 108, 111, 165, 119, 111, 114, 108, 100>>
  ```
  """
  @spec encode!(term(), keyword()) :: binary()
  def encode!(term, opts \\ []) do
    case encode(term, opts) do
      {:ok, binary} ->
        binary

      {:error, {:unsupported_type, type}} ->
        raise %EncodeError{message: "cannot encode unsupported type: #{inspect(type)}"}

      {:error, {:unsupported_atom, atom}} ->
        raise Msgpack.UnsupportedAtomError, atom: atom
    end
  end

  @doc """
  Decodes a MessagePack binary into an Elixir term.

  Returns `{:ok, term}` on success, or `{:error, reason}` on failure.

  ## Options

    * `:max_depth` - Sets a limit on the nesting level of arrays and maps to
    prevent stack exhaustion from maliciously crafted inputs.
    Defaults to `100`.

    * `:max_byte_size` - Sets a limit on the declared byte size of any single
    string, binary, array, or map to prevent memory exhaustion attacks.
    Defaults to `10_000_000` (10MB).

  ## Examples

  ### Standard Decoding

  For trusted inputs, you can decode directly without custom options.

  ```elixir
  iex> encoded = <<0x81, 0xA5, "hello", 0xA5, "world">>
  iex> Msgpack.decode(encoded)
  {:ok, %{"hello" => "world"}}
  ```

  ### Securely Handling Untrusted Input

  When decoding data from an external source, set limits to prevent
  denial-of-service attacks.

  A deeply nested payload may exhaust the process stack:

  ```elixir
  iex> payload = <<0x91, 0x91, 0x91, 1>> # [[[1]]]
  iex> Msgpack.decode(payload, max_depth: 2)
  {:error, {:max_depth_reached, 2}}
  ```

  A payload declaring a huge string can cause excessive memory allocation:

  ```elixir
  iex> payload = <<0xDB, 0xFFFFFFFF::32>> # A string of 4GB
  iex> Msgpack.decode(payload, max_byte_size: 1_000_000)
  {:error, {:max_byte_size_exceeded, 1_000_000}}
  ```

  ### Detecting Malformed Data

  The decoder will return an error tuple for malformed data, such as incomplete
  data or trailing bytes left over after a successful decode.

  ```elixir
  # A valid term followed by extra bytes
  iex> Msgpack.decode(<<192, 42>>)
  {:error, {:trailing_bytes, <<42>>}}

  # Incomplete map data
  iex> Msgpack.decode(<<0x81, 0xA3, "foo">>)
  {:error, :unexpected_eof}
  ```
  """
  @spec decode(binary(), keyword()) :: {:ok, term()} | {:error, error_reason()}
  def decode(binary, opts \\ []) do
    :telemetry.span(
      [:msgpack, :decode],
      %{opts: opts, byte_size: byte_size(binary)},
      fn ->
        result = Decoder.decode(binary, opts)

        case result do
          {:ok, term} ->
            {{:ok, term}, %{outcome: :ok}}

          {:error, reason} ->
            {{:error, reason}, %{outcome: :error}}
        end
      end
    )
  end

  @doc """
  Decodes a MessagePack binary, raising a `Msgpack.DecodeError` on failure.

  This variant raises an exception on failure. It is intended for use when a
  decoding failure is considered an exceptional state, for example, when
  decoding data from a trusted internal service that is assumed to be
  well-formed.

  For decoding data from external or untrusted sources where failure is a
  possible outcome, use `decode/2` to handle the returned `{:error, reason}`
  tuple.

  ## Options

  Accepts the same options as `decode/2`.

  ## Raises

    * `Msgpack.DecodeError` - If the binary is malformed, contains an unknown prefix, or has trailing bytes.

  ## Examples

  Basic success case:
  ```elixir
  iex> encoded = <<0x81, 0xA5, "hello", 0xA5, "world">>
  iex> Msgpack.decode!(encoded)
  %{"hello" => "world"}
  ```

  Failure case:
  ```elixir
  iex> Msgpack.decode!(<<192, 42>>)
  ** (Msgpack.DecodeError) Failed to decode MessagePack binary. Reason = {:trailing_bytes, "*"}
  ```
  """
  @spec decode!(binary(), keyword()) :: term()
  def decode!(binary, opts \\ []) do
    case decode(binary, opts) do
      {:ok, term} ->
        term

      {:error, reason} ->
        raise DecodeError, reason: reason
    end
  end

  def encode_stream(enumerable, opts \\ []) do
    StreamEncoder.encode(enumerable, opts)
  end

  def decode_stream(enumerable, opts \\ []) do
    StreamDecoder.decode(enumerable, opts)
  end
end
