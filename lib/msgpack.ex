defmodule Msgpack do
  alias Msgpack.Encoder
  alias Msgpack.UnsupportedAtomError
  alias Msgpack.EncodeError

  @type error_reason :: {:unsupported_type, term()} | {:malformed_binary, String.t()}

  @spec encode(term(), keyword()) :: {:ok, binary()} | {:error, {:unsupported_type, term()}}
  def encode(term, opts \\ []) do
    try do
      encoded_term = Encoder.encode(term, opts)
      {:ok, encoded_term}
    rescue
      e ->
        case e do
          %UnsupportedAtomError{atom: atom} ->
            {:error, {:unsupported_type, atom}}

          %FunctionClauseError{} ->
            {:error, {:unsupported_type, term}}

          _other ->
            reraise e, __STACKTRACE__
        end
    end
  end

  @spec encode!(term()) :: binary()
  def encode!(term) do
    case encode(term) do
      {:ok, binary} ->
        binary
      {:error, {:unsupported_type, type}} ->
        raise %EncodeError{message: "cannot encode unsupported type: #{inspect(type)}"}
    end
  end
end
