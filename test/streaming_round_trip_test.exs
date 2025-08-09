defmodule Msgpack.StreamingRoundTripTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Msgpack
  alias Msgpack.StreamEncoder
  alias Msgpack.StreamDecoder

  property "a round trip through the streaming API is lossless" do
    check all(terms <- list_of_encodable_terms(), chunk_size <- StreamData.integer(1..20)) do
      binaries =
        StreamEncoder.encode(terms)
        |> Stream.map(fn {:ok, binary} -> binary end)

      chunked_stream =
        binaries
        |> Enum.to_list()
        |> IO.iodata_to_binary()
        |> chunk_binary(chunk_size)

      decoded_terms =
        StreamDecoder.decode(chunked_stream)
        |> Enum.to_list()

      assert decoded_terms == terms
    end
  end

  defp list_of_encodable_terms do
    StreamData.list_of(encodable_term())
  end

  defp encodable_term do
    StreamData.one_of([
      StreamData.integer(-1_000_000..1_000_000),
      StreamData.string(:utf8, max_length: 50),
      StreamData.boolean(),
      StreamData.binary(max_length: 50),
      StreamData.constant(nil)
    ])
  end

  defp chunk_binary(binary, chunk_size) do
    Stream.unfold(binary, fn
      <<>> ->
        nil

      remaining ->
        size = min(chunk_size, byte_size(remaining))
        <<chunk::binary-size(size), rest::binary>> = remaining
        {chunk, rest}
    end)
  end
end
