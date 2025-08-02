defmodule MsgpackTest do
  use ExUnit.Case, async: true

  describe "encode/1" do
    test "successfully encodes a map with lists and atoms" do
      input = %{"tags" => [:a]}
      expected_binary = <<0x81, 0xa4, "tags", 0x91, 0xa1, "a">>

      result = Msgpack.encode(input)

      assert result == {:ok, expected_binary}
    end

    test "successfully encodes a tuple as an array" do
      input = {1, true, "hello"}
      expected_binary = <<0x93, 1, 0xc3, 0xa5, "hello">>

      result = Msgpack.encode(input)

      assert result == {:ok, expected_binary}
    end
  end
end
