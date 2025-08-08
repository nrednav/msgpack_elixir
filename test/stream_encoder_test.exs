defmodule Msgpack.StreamEncoderTest do
  use ExUnit.Case, async: true

  alias Msgpack.StreamEncoder

  test "encodes a stream of valid terms into ok-tuples" do
    terms = [1, "elixir", true]

    expected_result = [
      {:ok, Msgpack.encode!(1)},
      {:ok, Msgpack.encode!("elixir")},
      {:ok, Msgpack.encode!(true)}
    ]

    result = StreamEncoder.encode(terms) |> Enum.to_list()

    assert result == expected_result
  end

  test "handles unencodable terms by emitting an error tuple" do
    terms = [1, :water, 3]
    opts = [atoms: :error]

    expected_result = [
      {:ok, Msgpack.encode!(1)},
      {:error, {:unsupported_atom, :water}},
      {:ok, Msgpack.encode!(3)}
    ]

    result = StreamEncoder.encode(terms, opts) |> Enum.to_list()

    assert result == expected_result
  end

  test "returns an empty list when given an empty stream" do
    terms = []

    result = StreamEncoder.encode(terms) |> Enum.to_list()

    assert result == []
  end
end
