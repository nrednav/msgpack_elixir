defmodule Msgpack do
  @moduledoc """
  An implementation of the MessagePack serialization format.

  This module provides the main API for encoding Elixir terms into MessagePack
  binaries and decoding MessagePack binaries back into Elixir terms.

  ## Usage

  The primary functions are `encode/2` and `decode/2` (and their
  exception-raising variants `encode!/2` and `decode!/2`).

  ### Example

  ```elixir
  iex> data = %{"compact" => true, "schema" => 0}
  iex> {:ok, encoded} = Msgpack.encode(data)
  iex> Msgpack.decode(encoded)
  {:ok, %{"compact" => true, "schema" => 0}}
  ```
  """

  alias Msgpack.Encoder
  alias Msgpack.Decoder
  alias Msgpack.EncodeError
  alias Msgpack.DecodeError

  # Encoding errors
  @type error_reason ::
          {:unsupported_type, term()}
          | {:unsupported_atom, atom()}
          # Decoding errors
          | :unexpected_eof
          | {:unknown_prefix, byte()}
          | {:trailing_bytes, binary()}

  @doc """
  Encodes an Elixir term into a MessagePack binary.

  Returns `{:ok, binary}` on success, or `{:error, reason}` on failure.

  ## Options

    * `:atoms` - Controls how atoms are encoded.
      * `:string` (default) - Encodes atoms as MessagePack strings.
      * `:error` - Returns an `{:error, {:unsupported_atom, atom}}` tuple if an atom is encountered.

    * `:string_validation` - Controls whether to perform UTF-8 validation on binaries.
      * `true` (default) - Validates binaries and encodes them as the `str` type
      if they are valid UTF-8, otherwise encodes them as the `bin` type
      * `false` - Skips validation and encodes all binaries as the `str` type.
      This provides a significant performance increase but should only be used
      if you are certain that your data does not contain invalid UTF-8 strings.

  ## Examples

    iex> Msgpack.encode(%{hello: "world"})
    {:ok, <<129, 165, 104, 101, 108, 108, 111, 165, 119, 111, 114, 108, 100>>}

    iex> Msgpack.encode(:my_atom, atoms: :error)
    {:error, {:unsupported_atom, :my_atom}}
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

  ## Options

  Accepts the same options as `encode/2`.

  ## Raises

    * `Msgpack.EncodeError` - if an unsupported Elixir term is encountered.
    * `Msgpack.UnsupportedAtomError` - if an atom is encountered and the `:atoms` option is set to `:error`.

  ## Examples
    iex> Msgpack.encode!(%{hello: "world"})
    <<129, 165, 104, 101, 108, 108, 111, 165, 119, 111, 114, 108, 100>>
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

    iex> encoded = <<129, 165, 104, 101, 108, 108, 111, 165, 119, 111, 114, 108, 100>>

    iex> Msgpack.decode(encoded)
    {:ok, %{"hello" => "world"}}

    iex> Msgpack.decode(<<192, 42>>)
    {:error, {:trailing_bytes, <<42>>}}

    iex> Msgpack.decode(<<0x91, 0x91, 1>>, max_depth: 1)
    {:error, {:max_depth_reached, 1}}

    iex> Msgpack.decode(<<0xDB, 0xFFFFFFFF::32>>, max_byte_size: 1_000_000)
    {:error, {:max_byte_size_exceeded, 1_000_000}}
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

  ## Options

  Accepts the same options as `decode/2`.

  ## Raises

    * `Msgpack.DecodeError` - if the binary is malformed, contains an unknown prefix, or has trailing bytes.

  ## Examples

    iex> encoded = <<129, 165, 104, 101, 108, 108, 111, 165, 119, 111, 114, 108, 100>>

    iex> Msgpack.decode!(<<255>>)
    ** (Msgpack.DecodeError) unknown prefix: 255
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
end
