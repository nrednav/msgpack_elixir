defmodule Msgpack do
  alias Msgpack.Encoder

  @type error_reason :: {:unsupported_type, term()} | {:malformed_binary, String.t()}

  @spec encode(term()) :: {:ok, binary()} | {:error, {:unsupported_type, term()}}
  def encode(term) do
    Encoder.encode(term)
  end
end
