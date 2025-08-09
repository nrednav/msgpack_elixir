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
    single_binary = Enum.map_join(terms, &Msgpack.encode!/1)
    <<chunk1::binary-size(4), chunk2::binary>> = single_binary
    input_stream = [chunk1, chunk2]

    result = StreamDecoder.decode(input_stream) |> Enum.to_list()

    assert result == terms
  end

  test "returns an error when the stream ends with incomplete data" do
    binary = Msgpack.encode!("a guaranteed incomplete string")
    incomplete_binary = :binary.part(binary, 0, byte_size(binary) - 1)
    input_stream = [incomplete_binary]
    expected_result = [{:error, :unexpected_eof}]

    result = StreamDecoder.decode(input_stream) |> Enum.to_list()

    assert result == expected_result
  end
end
