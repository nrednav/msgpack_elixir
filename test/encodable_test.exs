defmodule Msgpack.EncodableTest do
  use ExUnit.Case, async: true

  alias Msgpack.EncodableTest.User
  alias Msgpack.EncodableTest.Product
  alias Msgpack

  test "successfully encodes a custom struct with a protocol implementation" do
    user = %User{id: 1, name: "Bob"}
    expected_binary = <<0x82, 0xA2, "id", 1, 0xA4, "name", 0xA3, "Bob">>

    assert Msgpack.encode(user) == {:ok, expected_binary}
  end

  test "returns an error when encoding a struct without a protocol implementation" do
    product = %Product{id: 1234}
    expected_error = {:error, {:unsupported_type, Product}}

    assert Msgpack.encode(product) == expected_error
  end
end
