defmodule Msgpack do
  alias Msgpack.Encoder
  alias Msgpack.EncodeError

  @type error_reason ::
    {:unsupported_type, term()}
    | {:unsupported_atom, atom()}

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
end
