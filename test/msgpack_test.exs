defmodule MsgpackTest do
  use ExUnit.Case, async: true

  use ExUnitProperties

  require StreamData

  defmodule Msgpack.EncodeError, do: defexception [:message]
  defmodule Msgpack.DecodeError, do: defexception [:message]

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

    test "returns an error tuple when trying to encode an unsupported type like a PID" do
      input = self()

      result = Msgpack.encode(input)

      assert result == {:error, {:unsupported_type, input}}
    end

    test "returns an error tuple when trying to encode a Reference" do
      input = make_ref()

      result = Msgpack.encode(%{"ref" => input})

      assert result == {:error, {:unsupported_type, input}}
    end
  end

  describe "encode/2" do
    test "with `atoms: :error` returns an error for atoms" do
      input = [:foo]

      result = Msgpack.encode(input, atoms: :error)

      assert result == {:error, {:unsupported_type, :foo}}
    end

    test "with `atoms: :string` (default) successfully encodes atoms" do
      input = [:foo]
      expected_binary = <<0x91, 0xa3, "foo">>

      result_with_option = Msgpack.encode(input, atoms: :error)
      result_with_default = Msgpack.encode(input)

      assert result_with_option == {:ok, expected_binary}
      assert result_with_default == {:ok, expected_binary}
    end
  end

  describe "decode/1" do
    test "successfully decodes a binary representing an array of an integer and a string" do
      input = <<0x92, 1, 0xa5, "hello">>
      expected_term = [1, "hello"]

      result = Msgpack.decode(input)

      assert result == {:ok, expected_term}
    end

    test "successfully decodes a binary representing a map" do
      input = <<0x81, 0xa3, "foo", 0xa3, "bar">>
      expected_term = %{"foo" => "bar"}

      result = Msgpack.decode(input)

      assert result == {:ok, expected_term}
    end

    test "returns a malformed binary error for incomplete data" do
      input = <<0x92, 1>>

      result = Msgpack.decode(input)

      assert match?({:error, {:malformed_binary, _reason}}, result)
    end

    test "returns a malformed binary error for an invalid format byte" do
      input = <<0xc1>>

      result = Msgpack.decode(input)

      assert match?({:error, {:malformed_binary, _reason}}, result)
    end
  end

  describe "decode/2" do
    test "respects the :max_depth option" do
      input = <<0x91, 0x91, 0x91, 1>>
      expected_term = [[[1]]]

      assert Msgpack.decode(input, max_depth: 3) == {:ok, expected_term}
      assert Msgpack.decode(input, max_depth: 4) == {:ok, expected_term}
      assert match?(
        {:error, {:max_depth_reached, 2}},
        Msgpack.decode(input, max_depth: 2)
      )
    end
  end

  describe "encode!/1" do
    test "returns the binary on successful encoding" do
      input = [1,2,3]
      expected_binary = <<0x93, 1, 2, 3>>

      assert Msgpack.encode!(input) == expected_binary
    end

    test "raises an error on failure" do
      input = self()

      assert_raise Msgpack.EncodeError, fn ->
        Msgpack.encode!(input)
      end
    end
  end

  describe "decode!/1" do
    test "returns the binary on successful encoding" do
      input = <<0x93, 1, 2, 3>>
      expected_term = [1,2,3]

      assert Msgpack.decode!(input) == expected_term
    end

    test "raises an error on failure" do
      input = <<0x92, 1>>

      assert_raise Msgpack.DecodeError, fn ->
        Msgpack.decode!(input)
      end
    end
  end

  describe "Property Tests" do
    defp supported_term_generator do
      leaf_generators = [
        StreamData.constant(nil),
        StreamData.boolean(),
        StreamData.integer(),
        StreamData.float(),
        StreamData.string(:utf8),
        StreamData.binary(),
        StreamData.map(StreamData.atom(), &Atom.to_string/1)
      ]

      StreamData.recursive(StreamData.one_of(leaf_generators), fn inner_generator ->
        [
          StreamData.list_of(inner_generator),
          StreamData.map_of(StreamData.string(:utf8), inner_generator),
          StreamData.tuple_of(inner_generator)
        ]
      end)
    end

    property "encode! |> decode! is a lossless round trip for supported types" do
      check all term <- supported_term_generator(), max_run: 500 do
        result =
          term
          |> Msgpack.encode!()
          |> Msgpack.decode!()

        # Special case for floats due to potential precision issues
        if is_float(term) and is_float(result) do
          assert_in_delta term, result, 0.000001
        else
          assert result == term
        end
      end
    end
  end
end
