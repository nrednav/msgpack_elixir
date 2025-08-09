defmodule Msgpack.StreamDecoder do
  @moduledoc """
  Decodes a stream of MessagePack binaries into a stream of Elixir terms.

  This module is designed to handle large sequences of MessagePack objects that
  arrive in chunks, such as from a network socket or a large file.

  It incrementally parses the incoming binaries and emits complete Elixir terms
  as they are decoded.

  ## Capabilities

    * **Buffering:** The module internally buffers data, allowing a single
    MessagePack object to be split across multiple chunks in the input stream.
    * **Error Handling:** If the stream finishes while an object is only
    partially decoded, the last element emitted by the stream will be the tuple
    `{:error, :unexpected_eof}`.

  This module can be used together with `Msgpack.StreamEncoder` to create a lazy
  serialization and deserialization pipeline.
  """

  alias Msgpack.Decoder
  alias Msgpack.Decoder.Internal

  @typedoc """
  A stream that yields decoded Elixir terms or a final error tuple.

  The stream will produce any t:term/0 that can be decoded from the input.

  If the input enumerable finishes while a term is only partially decoded, the
  last element in the stream will be {:error, :unexpected_eof}.
  """
  @type t :: Stream.t(term() | {:error, :unexpected_eof})

  @typedoc "Options passed to the decoder for each object."
  @type opts_t :: keyword()

  @doc """
  Lazily decodes an enumerable of MessagePack binaries into a stream of Elixir
  terms.

  ## Parameters

    * `enumerable`: An `Enumerable` that yields chunks of a MessagePack binary
    stream (e.g., `f:File.stream/3` or a list of binaries).
    * `opts`: A keyword list of options passed to the underlying decoder.

  ## Return Value

  Returns a lazy `Stream` that emits Elixir terms as they are decoded.

  If the input stream ends with incomplete data, the last item emitted will be
  an error tuple `{:error, :unexpected_eof}`.

  ## Options

  This function accepts the same options as `Msgpack.decode/2`, which are
  applied to the decoding of each object in the stream:

    * `:max_depth`: Sets a limit on the nesting level of arrays and maps.
      Defaults to `100`.
    * `:max_byte_size`: Sets a limit on the declared byte size of any single
    string, binary, array, or map.
      Defaults to `10_000_000` (10MB).

  ## Examples

  ### Standard Usage

  ```elixir
  iex> objects = [1, "elixir", true]
  iex> stream = Enum.map(objects, &Msgpack.encode!/1)
  iex> Msgpack.StreamDecoder.decode(stream) |> Enum.to_list()
  [1, "elixir", true]
  ```

  ### Handling Incomplete Streams

  ```elixir
  iex> incomplete_stream = [<<0x91>>] # Array header + no elements
  iex> Msgpack.StreamDecoder.decode(incomplete_stream) |> Enum.to_list()
  [{:error, :unexpected_eof}]
  ```
  """
  @spec decode(Enumerable.t(binary()), opts_t()) :: t()
  def decode(enumerable, opts \\ []) do
    start_fun = fn ->
      merged_opts = Keyword.merge(Decoder.default_opts(), opts)
      {<<>>, merged_opts}
    end

    stream_with_eof = Stream.concat(enumerable, [:eof])
    transform_fun = &transform_chunk/2

    Stream.transform(stream_with_eof, start_fun.(), transform_fun)
  end

  @doc false
  @spec transform_chunk(
          binary() | :eof,
          {binary(), opts_t()}
        ) ::
          {list(term() | {:error, :unexpected_eof}), {binary(), opts_t() | nil}}
  defp transform_chunk(:eof, {<<>>, _opts}) do
    {[], {<<>>, nil}}
  end

  defp transform_chunk(:eof, {buffer, _opts}) do
    {[{:error, :unexpected_eof}], {buffer, nil}}
  end

  defp transform_chunk(chunk, {buffer, opts}) do
    {decoded_terms, leftover_buffer} = do_transform(buffer <> chunk, opts, [])
    {decoded_terms, {leftover_buffer, opts}}
  end

  @doc false
  @spec do_transform(binary(), opts_t(), list(term())) :: {list(term()), binary()}
  defp do_transform(<<>>, _opts, acc) do
    {Enum.reverse(acc), <<>>}
  end

  defp do_transform(buffer, opts, acc) do
    case Internal.decode(buffer, opts) do
      {:ok, {term, rest}} ->
        do_transform(rest, opts, [term | acc])

      {:error, _reason} ->
        {Enum.reverse(acc), buffer}
    end
  end
end
