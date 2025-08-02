defmodule MsgpackTest do
  use ExUnit.Case, async: true

  use ExUnitProperties

  require StreamData

  defmodule Msgpack.EncodeError, do: defexception [:message]
  defmodule Msgpack.DecodeError, do: defexception [:message]
  defmodule Msgpack.Ext do
    defstruct [:type, :data]
  end

  alias Msgpack.Ext

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

      result_with_option = Msgpack.encode(input, atoms: :string)
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

    test "successfully decodes a float 32 binary" do
      input = <<0xca, 0x3FC00000::32>>
      expected_term = 1.5

      result = Msgpack.decode(input)

      assert result == {:ok, expected_term}
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

    test "returns an error when a declared string size exceeds :max_byte_size" do
      input = <<0xdb, 0xFFFFFFFF::32>>
      limit = 1_000_000 # 1MB limit

      result = Msgpack.decode(input, max_byte_size: limit)

      assert result == {:error, {:max_byte_size_exceeded, limit}}
    end

    test "returns an error when a declared array size exceeds :max_byte_size" do
      input = <<0xdd, 0xFFFFFFFF::32>>
      limit = 1_000_000 # 1MB limit

      result = Msgpack.decode(input, max_byte_size: limit)

      assert result == {:error, {:max_byte_size_exceeded, limit}}
    end

    test "successfully decodes data within byte size limit" do
      input = <<0xa5, "hello">>
      limit = 10

      assert Msgpack.decode(input, max_byte_size: limit) == {:ok, "hello"}
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

  describe "Msgpack.Ext and Timestamps" do
    test "provides a lossless round trip for custom extension types" do
      input = %Ext{type: 10, data: <<1, 2, 3, 4>>}

      result =
        input
        |> Msgpack.encode!()
        |> Msgpack.decode!()

      assert result == input
    end

    test "provides a lossless round trip for NaiveDateTime via the Timestamp extension" do
      input = ~N[2025-08-02 10:00:00.123456]

      result =
        input
        |> Msgpack.encode!()
        |> Msgpack.decode!()

      assert result == input
    end

    test "decodes a timestamp with nanoseconds into a NaiveDateTime" do
      input = <<0xd7, -1::signed, 0x000001F4653B8A10::64>>
      expected_datetime = ~N[2023-10-27 10:00:00.000000500]

      {:ok, result} = Msgpack.decode(input)

      assert result == expected_datetime
    end

    test "decodes a timestamp 96 (pre-epoch) into a NaiveDateTime" do
      input = <<0xc7, -1::signed-8, 123::signed-32, -150_427_200::signed-64>>
      expected_datetime = ~N[1965-03-26 12:00:00.000000123]

      {:ok, result} = Msgpack.decode(input)

      assert result == expected_datetime
    end
  end

  describe "Observability" do
    test "emits :encode, :stop event with safe metadata on successful encoding" do
      test_pid = self()
      handler_id = "test-handler-#{System.unique_integer()}"

      :telemetry.attach(handler_id, [:msgpack, :encode, :stop], fn _, m, meta, _ ->
        send(test_pid, {:telemetry_event, m, meta})
      end, nil)

      on_exit(fn -> :telemetry.detach(handler_id) end)

      input = %{password: "s3cr3t", data: <<1, 2, 3>>}

      {:ok, output} = Msgpack.encode(input)

      assert_receive {:telemetry_event, measurements, metadata}
      assert is_integer(measurements.duration)

      refute Map.has_key?(metadata, :input)
      refute Map.has_key?(metadata, :output)

      assert metadata.input_term_type == Map
      assert metadata.output_byte_size == byte_size(output)
    end

    test "emits :decode, :exception with safe metadata on decoding failure" do
      test_pid = self()
      handler_id = "test-handler-#{System.unique_integer()}"

      :telemetry.attach(handler_id, [:msgpack, :decode, :exception], fn _, m, meta, _ ->
        send(test_pid, {:telemetry_event, m, meta})
      end, nil)

      on_exit(fn -> :telemetry.detach(handler_id) end)

      input = <<0xc1>>

      try, do: Msgpack.decode!(input), rescue: _ -> :ok

      assert_receive {:telemetry_event, measurements, metadata}
      assert is_integer(measurements.duration)

      refute Map.has_key?(metadata, :input)

      assert metadata.kind == :error
      assert metadata.reason.__struct__ == Msgpack.DecodeError
      assert metadata.input_byte_size == byte_size(input)
    end
  end

  describe "Edge Case Data Types" do
    test "provides a lossless round trip for Infinity" do
      input = 1.0 / 0.0

      assert Float.is_infinite(input)

      result =
        input
        |> Msgpack.encode!()
        |> Msgpack.decode!()

      assert result == input
    end

    test "provides a lossless round trip for negative Infinity" do
      input = -1.0 / 0.0

      assert Float.is_infinite(input)

      result =
        input
        |> Msgpack.encode!()
        |> Msgpack.decode!()

      assert result == input
    end

    test "provides a lossless round trip for NaN" do
      input = 0.0 / 0.0

      assert Float.is_nan(input)

      result =
        input
        |> Msgpack.encode!()
        |> Msgpack.decode!()

      assert Float.is_nan(result)
    end
  end
end
