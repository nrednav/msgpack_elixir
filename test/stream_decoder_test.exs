defmodule Msgpack.StreamDecoderTest do
  use ExUnit.Case, async: true

  alias Msgpack.StreamDecoder

  test "decodes a stream of complete objects" do
    terms = [1, "elixir", true, %{"a" => 1}]
    input_stream = Enum.map(terms, &Msgpack.encode!/1)

    result = StreamDecoder.decode(input_stream) |> Enum.to_list()

    assert result == terms
  end

  test "decodes a stream where objects cross chunk boundaries" do
    terms = [123, "elixir", true, %{"a" => 1}]
    single_binary = Enum.map(terms, &Msgpack.encode!/1) |> Enum.join()
    <<chunk1::binary-size(4), chunk2::binary>> = single_binary
    input_stream = [chunk1, chunk2]

    result = StreamDecoder.decode(input_stream) |> Enum.to_list()

    assert result == terms
  end
end
