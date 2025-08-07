defmodule Msgpack.StreamDecoder do
  alias Msgpack.Decoder
  alias Msgpack.Decoder.Internal

  @doc """
  Decodes a stream of MessagePack binaries into a stream of Elixir terms
  """
  def decode(enumerable, opts \\ []) do
    merged_opts = Keyword.merge(Decoder.default_options(), opts)

    initial_acc = %{
      buffer: <<>>,
      opts: merged_opts
    }

    Stream.transform(enumerable, initial_acc, &process_chunk/2)
  end

  defp process_chunk(chunk, acc) do
    buffer = acc.buffer <> chunk
    opts = acc.opts

    {decoded_terms, leftover_buffer} = decode_from_buffer(buffer, opts, [])

    {decoded_terms, %{acc | buffer: leftover_buffer}}
  end

  defp decode_from_buffer(buffer, opts, decoded_acc) do
    try do
      case Internal.decode(buffer, opts) do
        {:ok, {term, rest}} ->
          decode_from_buffer(rest, opts, [term | decoded_acc])

        {:error, :unexpected_eof} ->
          {Enum.reverse(decoded_acc), buffer}

        {:error, reason} ->
          {Enum.reverse(decoded_acc, [{:error, reason}]), <<>>}
      end
    catch
      {:error, reason} ->
        {Enum.reverse(decoded_acc, [{:error, reason}]), <<>>}
    end
  end
end
