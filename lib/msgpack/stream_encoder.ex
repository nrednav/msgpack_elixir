defmodule Msgpack.StreamEncoder do
  @moduledoc """
  Lazily encodes a stream of Elixir terms into a stream of MessagePack binaries.

  This module is the counterpart to `Msgpack.StreamDecoder`. It processes an
  enumerable item by item, making it memory-efficient for encoding large
  collections or infinite streams without loading the entire dataset into
  memory.

  Each item in the output stream is a result tuple, either `{:ok, binary}` for
  a successful encoding or `{:error, reason}` if an individual term could
  not be encoded.
  """

  @doc """
  Lazily encodes an enumerable of Elixir terms into a stream of result tuples.

  ## Parameters

    * `enumerable`: An `Enumerable` that yields Elixir terms to be encoded.
    * `opts`: A keyword list of options passed to the underlying encoder for each term.

  ## Return Value

  Returns a lazy `Stream` that emits result tuples. For each term in the
  input enumerable, the stream will contain either:
    * `{:ok, binary}` - On successful encoding.
    * `{:error, reason}` - If the term cannot be encoded.

  ## Options

  This function accepts the same options as `Msgpack.encode/2`. See the
  documentation for `Msgpack.encode/2` for a full list.

  ## Examples

  ### Standard Usage

  ```elixir
  iex> terms = [1, "elixir"]
  iex> Msgpack.StreamEncoder.encode(terms) |> Enum.to_list()
  [
    {:ok, <<1>>},
    {:ok, <<166, 101, 108, 105, 120, 105, 114>>}
  ]
  ```

  ### Handling Unencodable Terms

  ```elixir
  iex> terms = [1, :elixir, 4]
  iex> Msgpack.StreamEncoder.encode(terms, atoms: :error) |> Enum.to_list()
  [
    {:ok, <<1>>},
    {:error, {:unsupported_atom, :elixir}},
    {:ok, <<4>>}
  ]
  ```
  """
  def encode(enumerable, opts \\ []) do
    Stream.map(enumerable, &Msgpack.encode(&1, opts))
  end
end
