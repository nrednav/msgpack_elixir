defmodule Msgpack.StreamDecoder do
  alias Msgpack.Decoder
  alias Msgpack.Decoder.Internal

  @doc """
  Decodes a stream of MessagePack binaries into a stream of Elixir terms.
  """
  def decode(enumerable, opts \\ []) do
    start_fun = fn ->
      merged_opts = Keyword.merge(Decoder.default_opts(), opts)
      {<<>>, merged_opts}
    end

    stream_with_eof = Stream.concat(enumerable, [:eof])
    transform_fun = &transform_chunk/2

    Stream.transform(stream_with_eof, start_fun.(), transform_fun)
  end

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
