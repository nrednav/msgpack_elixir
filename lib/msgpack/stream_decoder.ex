defmodule Msgpack.StreamDecoder do
  alias Msgpack.Decoder
  alias Msgpack.Decoder.Internal

  @doc """
  Decodes a stream of MessagePack binaries into a stream of Elixir terms.
  """
  def decode(enumerable, opts \\ []) do
    merged_opts = Keyword.merge(Decoder.default_options(), opts)

    initial_acc = %{
      enum: enumerable,
      buffer: <<>>,
      opts: merged_opts
    }

    Stream.unfold(initial_acc, &decode_one_or_fetch/1)
  end

  defp decode_one_or_fetch(state) do
    try do
      case Internal.decode(state.buffer, state.opts) do
        {:ok, {term, rest}} ->
          {term, %{state | buffer: rest}}

        {:error, :unexpected_eof} ->
          case Enum.fetch(state.enum, 0) do
            {:ok, chunk} ->
              new_buffer = state.buffer <> chunk
              remaining_enum = Stream.drop(state.enum, 1)
              decode_one_or_fetch(%{state | buffer: new_buffer, enum: remaining_enum})

            :error ->
              if byte_size(state.buffer) > 0 do
                {{:error, :unexpected_eof}, %{state | buffer: <<>>}}
              else
                nil
              end
          end
      end
    catch
      {:error, reason} ->
        {{:error, reason}, %{state | buffer: <<>>}}
    end
  end
end
