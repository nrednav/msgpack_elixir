defmodule Msgpack.StreamEncoder do
  @doc """
  Encodes a stream of Elixir terms into a stream of MessagePack binaries.
  """
  def encode(enumerable, opts \\ []) do
    Stream.map(enumerable, &Msgpack.encode(&1, opts))
  end
end
