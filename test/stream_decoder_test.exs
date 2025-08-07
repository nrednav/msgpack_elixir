defmodule Msgpack.StreamDecoderTest do
  use ExUnit.Case, async: true

  alias Msgpack.StreamDecoder

  test "decodes a stream of complete objects" do
    terms = [1, "elixir", true, %{"a" => 1}]
    input_stream = Enum.map(terms, &Msgpack.encode!/1)

    result = StreamDecoder.decode(input_stream) |> Enum.to_list()

    assert result == terms
  end
end
