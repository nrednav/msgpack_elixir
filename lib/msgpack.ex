defmodule Msgpack do
  alias Msgpack.Encoder
  alias Msgpack.Decoder
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

  @doc """
  Encodes an Elixir term into a MessagePack binary.

  Returns `{:ok, binary}` on success, or `{:error, reason}` on failure.

  ## Options

    * `:atoms` - Controls how atoms are encoded.
      * `:string` (default) - Encodes atoms as MessagePack strings.
      * `:error` - Returns an `{:error, {:unsupported_atom, atom}}` tuple if an atom is encountered.

  ## Examples

    iex> Msgpack.encode(%{hello: "world"})
    {:ok, <<129, 165, 104, 101, 108, 108, 111, 165, 119, 111, 114, 108, 100>>}
  """
  @spec encode(term(), keyword()) :: {:ok, binary()} | {:error, error_reason()}
  def encode(term, opts \\ []) do
    with {:ok, iodata} <- Encoder.encode(term, opts) do
      {:ok, IO.iodata_to_binary(iodata)}
    end
  end

  @doc """
  Encodes an Elixir term into a MessagePack binary, raising an error on failure.

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
  """
  @spec decode(binary(), keyword()) :: {:ok, term()} | {:error, error_reason()}
  def decode(binary, opts \\ []) do
    Decoder.decode(binary, opts)
  end

  @doc """
  Decodes a MessagePack binary, raising a `Msgpack.DecodeError` on failure.
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
