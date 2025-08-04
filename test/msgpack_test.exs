defmodule MsgpackTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  require StreamData

  alias Msgpack
  alias Msgpack.Ext

  describe "encode/2" do
    test "successfully encodes a map with lists and atoms" do
      assert_encode(%{"tags" => [:a]}, <<0x81, 0xA4, "tags", 0x91, 0xA1, "a">>)
    end

    test "successfully encodes a tuple as an array" do
      assert_encode({1, true, "hello"}, <<0x93, 1, 0xC3, 0xA5, "hello">>)
    end

    test "returns an error tuple when trying to encode an unsupported type like a PID" do
      input = self()
      assert_encode_error(input, {:unsupported_type, input})
    end

    test "returns an error tuple when trying to encode a Reference" do
      input = make_ref()
      assert_encode_error(input, {:unsupported_type, input})
    end

    test "with `atoms: :string` (default) successfully encodes atoms" do
      assert_encode([:foo], <<0x91, 0xA3, "foo">>)
    end

    test "with `atoms: :error` returns an error for atoms" do
      assert_encode_error([:foo], {:unsupported_atom, :foo}, atoms: :error)
    end
  end

  describe "decode/2" do
    test "successfully decodes a binary representing an array of an integer and a string" do
      assert_decode(<<0x92, 1, 0xA5, "hello">>, [1, "hello"])
    end

    test "successfully decodes a binary representing a map" do
      assert_decode(<<0x81, 0xA3, "foo", 0xA3, "bar">>, %{"foo" => "bar"})
    end

    test "returns a malformed binary error for incomplete data" do
      assert_decode_error(<<0x92, 1>>, :unexpected_eof)
    end

    test "returns a malformed binary error for an invalid format byte" do
      assert_decode_error(<<0xC1>>, {:unknown_prefix, 193})
    end

    test "successfully decodes a float 32 binary" do
      assert_decode(<<0xCA, 0x3FC00000::32>>, 1.5)
    end

    test "respects the :max_depth option" do
      input = <<0x91, 0x91, 0x91, 1>>
      expected_term = [[[1]]]

      assert_decode(input, expected_term, max_depth: 3)
      assert_decode(input, expected_term, max_depth: 4)
      assert_decode_error(input, {:max_depth_reached, 2}, max_depth: 2)
    end

    test "returns an error when a declared string size exceeds :max_byte_size" do
      input = <<0xDB, 0xFFFFFFFF::32>>
      limit = 1_000_000

      assert_decode_error(input, {:max_byte_size_exceeded, limit}, max_byte_size: limit)
    end

    test "returns an error when a declared array size exceeds :max_byte_size" do
      input = <<0xDD, 0xFFFFFFFF::32>>
      limit = 1_000_000

      assert_decode_error(input, {:max_byte_size_exceeded, limit}, max_byte_size: limit)
    end

    test "successfully decodes data within byte size limit" do
      input = <<0xA5, "hello">>
      limit = 10

      assert_decode(input, "hello", max_byte_size: limit)
    end
  end

  describe "encode!/2" do
    test "returns the binary on successful encoding" do
      input = [1, 2, 3]
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

  describe "decode!/2" do
    test "returns the binary on successful encoding" do
      input = <<0x93, 1, 2, 3>>
      expected_term = [1, 2, 3]

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
      StreamData.sized(&do_supported_term_generator/1)
    end

    defp do_supported_term_generator(size) do
      leaf_generators = [
        StreamData.constant(nil),
        StreamData.boolean(),
        StreamData.integer(),
        StreamData.float(),
        StreamData.string(:alphanumeric, max_length: 128),
        StreamData.binary(max_length: 128),
        StreamData.atom(:alphanumeric) |> StreamData.map(&Atom.to_string/1)
      ]

      leaf_generator = StreamData.one_of(leaf_generators)

      if size == 0 do
        leaf_generator
      else
        inner_generator = do_supported_term_generator(size - 1)

        container_generators = [
          StreamData.list_of(inner_generator, max_length: 3),
          StreamData.map_of(
            StreamData.string(:alphanumeric, max_length: 64),
            inner_generator,
            max_length: 3
          ),
          StreamData.tuple({inner_generator})
        ]

        StreamData.one_of([leaf_generator | container_generators])
      end
    end

    property "encode! |> decode! is a lossless round trip for supported types" do
      check all(term <- supported_term_generator(), max_run: 500, max_size: 30) do
        expected = transform_tuples_to_lists(term)

        result =
          term
          |> Msgpack.encode!()
          |> Msgpack.decode!()

        # Special case for floats due to potential precision issues
        if is_float(expected) and is_float(result) do
          assert_in_delta expected, result, 0.000001
        else
          assert result == expected
        end
      end
    end
  end

  describe "Extensions & Timestamps" do
    test "provides a lossless round trip for custom extension types" do
      input = %Ext{type: 10, data: <<1, 2, 3, 4>>}
      result = input |> Msgpack.encode!() |> Msgpack.decode!()
      assert result == input
    end

    test "provides a lossless round trip for NaiveDateTime via the Timestamp extension" do
      input = ~N[2025-08-02 10:00:00.123456]
      result = input |> Msgpack.encode!() |> Msgpack.decode!()
      assert result == input
    end

    test "decodes a timestamp 96 (pre-epoch) into a NaiveDateTime" do
      timestamp_96_binary = <<0xC7, 12, -1::signed-8, 0::unsigned-32, -315_619_200::signed-64>>
      {:ok, decoded} = Msgpack.decode(timestamp_96_binary)
      assert decoded == ~N[1960-01-01 00:00:00]
    end

    test "encodes and decodes a timestamp 32 correctly" do
      input = ~N[2022-01-01 12:00:00]
      expected_binary = <<0xD6, -1::signed-8, 1_641_038_400::unsigned-32>>

      assert_encode(input, expected_binary)
      assert_decode(expected_binary, input)
    end
  end

  describe "Edge Case Data Types" do
    test "provides a lossless round trip for Infinity" do
      input = <<0x7FF0000000000000::float-64>>
      result = input |> Msgpack.encode!() |> Msgpack.decode!()
      assert result == input
    end

    test "provides a lossless round trip for negative Infinity" do
      input = <<0xFFF0000000000000::float-64>>
      result = input |> Msgpack.encode!() |> Msgpack.decode!()
      assert result == input
    end

    test "provides a lossless round trip for NaN" do
      input = <<0x7FF8000000000001::float-64>>
      result = input |> Msgpack.encode!() |> Msgpack.decode!()
      assert result == result
    end
  end

  # ==== Helpers ====

  defp assert_encode(input, expected_binary) do
    assert Msgpack.encode(input) == {:ok, expected_binary}
  end

  defp assert_encode_error(input, expected_reason, opts \\ []) do
    assert Msgpack.encode(input, opts) == {:error, expected_reason}
  end

  defp assert_decode(input_binary, expected_term, opts \\ []) do
    assert Msgpack.decode(input_binary, opts) == {:ok, expected_term}
  end

  defp assert_decode_error(input_binary, expected_reason, opts \\ []) do
    assert Msgpack.decode(input_binary, opts) == {:error, expected_reason}
  end

  defp transform_tuples_to_lists(term) do
    cond do
      is_tuple(term) ->
        term |> Tuple.to_list() |> Enum.map(&transform_tuples_to_lists/1)

      is_list(term) ->
        Enum.map(term, &transform_tuples_to_lists/1)

      is_map(term) ->
        Map.new(term, fn {key, value} ->
          {transform_tuples_to_lists(key), transform_tuples_to_lists(value)}
        end)

      true ->
        term
    end
  end
end
