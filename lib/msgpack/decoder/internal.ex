defmodule Msgpack.Decoder.Internal do
  @moduledoc false

  # The number of gregorian seconds from year 0 to the Unix epoch. This is a constant.
  @epoch_offset :calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})

  # ==== Nil ====
  def decode(<<0xC0, rest::binary>>, _opts), do: {:ok, {nil, rest}}

  # ==== Boolean ====
  def decode(<<0xC3, rest::binary>>, _opts), do: {:ok, {true, rest}}
  def decode(<<0xC2, rest::binary>>, _opts), do: {:ok, {false, rest}}

  # ==== Integers ====
  # ==== Positive Fixint ====
  def decode(<<int::8, rest::binary>>, _opts) when int < 128 do
    {:ok, {int, rest}}
  end

  # ==== Negative Fixint ====
  def decode(<<int::signed-8, rest::binary>>, _opts) when int >= -32 and int < 0 do
    {:ok, {int, rest}}
  end

  # ==== Unsigned Integers ====
  def decode(<<0xCC, int::8, rest::binary>>, _opts), do: {:ok, {int, rest}}
  def decode(<<0xCD, int::16, rest::binary>>, _opts), do: {:ok, {int, rest}}
  def decode(<<0xCE, int::32, rest::binary>>, _opts), do: {:ok, {int, rest}}
  def decode(<<0xCF, int::64, rest::binary>>, _opts), do: {:ok, {int, rest}}

  # ==== Signed Integers ====
  def decode(<<0xD0, int::signed-8, rest::binary>>, _opts), do: {:ok, {int, rest}}
  def decode(<<0xD1, int::signed-16, rest::binary>>, _opts), do: {:ok, {int, rest}}
  def decode(<<0xD2, int::signed-32, rest::binary>>, _opts), do: {:ok, {int, rest}}
  def decode(<<0xD3, int::signed-64, rest::binary>>, _opts), do: {:ok, {int, rest}}

  # ==== Floats ====
  def decode(<<0xCA, float::float-32, rest::binary>>, _opts), do: {:ok, {float, rest}}
  def decode(<<0xCB, float::float-64, rest::binary>>, _opts), do: {:ok, {float, rest}}

  # ==== Strings ====
  def decode(<<prefix, rest::binary>>, opts) when prefix >= 0xA0 and prefix <= 0xBF do
    size = prefix - 0xA0
    decode_string(rest, size, opts)
  end

  def decode(<<0xD9, size::8, rest::binary>>, opts), do: decode_string(rest, size, opts)
  def decode(<<0xDA, size::16, rest::binary>>, opts), do: decode_string(rest, size, opts)
  def decode(<<0xDB, size::32, rest::binary>>, opts), do: decode_string(rest, size, opts)

  # ==== Raw Binary ====
  def decode(<<0xC4, size::8, rest::binary>>, opts), do: decode_binary(rest, size, opts)
  def decode(<<0xC5, size::16, rest::binary>>, opts), do: decode_binary(rest, size, opts)
  def decode(<<0xC6, size::32, rest::binary>>, opts), do: decode_binary(rest, size, opts)

  # ==== Arrays ====
  def decode(<<prefix, rest::binary>>, opts) when prefix >= 0x90 and prefix <= 0x9F do
    size = prefix - 0x90
    decode_array(rest, size, opts)
  end

  def decode(<<0xDC, size::16, rest::binary>>, opts), do: decode_array(rest, size, opts)
  def decode(<<0xDD, size::32, rest::binary>>, opts), do: decode_array(rest, size, opts)

  # ==== Maps ====
  def decode(<<prefix, rest::binary>>, opts) when prefix >= 0x80 and prefix <= 0x8F do
    size = prefix - 0x80
    decode_map(rest, size, opts)
  end

  def decode(<<0xDE, size::16, rest::binary>>, opts), do: decode_map(rest, size, opts)
  def decode(<<0xDF, size::32, rest::binary>>, opts), do: decode_map(rest, size, opts)

  # ==== Extensions & Timestamps ====
  # ==== Fixext ====
  def decode(<<0xD4, type::signed-8, data::binary-size(1), rest::binary>>, opts),
    do: decode_ext(type, data, rest, opts)

  def decode(<<0xD5, type::signed-8, data::binary-size(2), rest::binary>>, opts),
    do: decode_ext(type, data, rest, opts)

  def decode(<<0xD6, type::signed-8, data::binary-size(4), rest::binary>>, opts),
    do: decode_ext(type, data, rest, opts)

  def decode(<<0xD7, type::signed-8, data::binary-size(8), rest::binary>>, opts),
    do: decode_ext(type, data, rest, opts)

  def decode(<<0xD8, type::signed-8, data::binary-size(16), rest::binary>>, opts),
    do: decode_ext(type, data, rest, opts)

  # ==== Ext ====
  def decode(<<0xC7, len::8, type::signed-8, data::binary-size(len), rest::binary>>, opts),
    do: decode_ext(type, data, rest, opts)

  def decode(<<0xC8, len::16, type::signed-8, data::binary-size(len), rest::binary>>, opts),
    do: decode_ext(type, data, rest, opts)

  def decode(<<0xC9, len::32, type::signed-8, data::binary-size(len), rest::binary>>, opts),
    do: decode_ext(type, data, rest, opts)

  # ==== Unknown types ====
  def decode(<<prefix, _rest::binary>>, _opts) do
    {:error, {:unknown_prefix, prefix}}
  end

  def decode(<<>>, _opts) do
    {:error, :unexpected_eof}
  end

  # ==== Helpers ====
  def decode_string(binary, size, opts) do
    if max_size = opts[:max_byte_size], do: check_byte_size(size, max_size)

    case binary do
      <<string::binary-size(size), rest::binary>> ->
        {:ok, {string, rest}}

      _ ->
        {:error, :unexpected_eof}
    end
  end

  def decode_binary(binary, size, opts) do
    if max_size = opts[:max_byte_size], do: check_byte_size(size, max_size)

    case binary do
      <<bin::binary-size(size), rest::binary>> ->
        {:ok, {bin, rest}}

      _ ->
        {:error, :unexpected_eof}
    end
  end

  def decode_array(binary, size, opts) do
    depth = opts[:depth] || 0

    check_depth(depth, opts[:max_depth])
    check_byte_size(size, opts[:max_byte_size])

    new_opts = Keyword.put(opts, :depth, depth + 1)

    decode_many(binary, size, [], new_opts)
  end

  def decode_map(binary, size, opts) do
    depth = opts[:depth] || 0

    check_depth(depth, opts[:max_depth])
    check_byte_size(size * 2, opts[:max_byte_size])

    new_opts = Keyword.put(opts, :depth, depth + 1)

    with {:ok, {kv_pairs, rest}} <- decode_many(binary, size * 2, [], new_opts) do
      map =
        Enum.chunk_every(kv_pairs, 2)
        |> Enum.map(&List.to_tuple/1)
        |> Enum.into(%{})

      {:ok, {map, rest}}
    end
  end

  # Recursively decodes `count` terms from the binary
  def decode_many(binary, 0, acc, _opts) do
    {:ok, {Enum.reverse(acc), binary}}
  end

  def decode_many(binary, count, acc, opts) do
    case decode(binary, opts) do
      {:ok, {term, rest}} ->
        decode_many(rest, count - 1, [term | acc], opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def decode_ext(-1, data, rest, _opts) do
    {:ok, {decode_timestamp(data), rest}}
  end

  def decode_ext(type, data, rest, _opts) do
    {:ok, {%Msgpack.Ext{type: type, data: data}, rest}}
  end

  # timestamp 32: 4 bytes (32-bit unsigned integer seconds)
  def decode_timestamp(<<unix_seconds::unsigned-32>>) do
    gregorian_seconds = unix_seconds + @epoch_offset
    erlang_datetime = :calendar.gregorian_seconds_to_datetime(gregorian_seconds)
    NaiveDateTime.from_erl!(erlang_datetime)
  end

  # timestamp 64: 8 bytes (30-bit nanoseconds + 34-bit seconds)
  def decode_timestamp(<<data::unsigned-64>>) do
    nanoseconds = :erlang.bsr(data, 34)

    if nanoseconds > 999_999_999 do
      throw({:error, :invalid_timestamp})
    else
      unix_seconds = :erlang.band(data, 0x00000003_FFFFFFFF)
      gregorian_seconds = unix_seconds + @epoch_offset
      erlang_datetime = :calendar.gregorian_seconds_to_datetime(gregorian_seconds)
      base_datetime = NaiveDateTime.from_erl!(erlang_datetime)

      if nanoseconds > 0 do
        microseconds = div(nanoseconds, 1000)
        %{base_datetime | microsecond: {microseconds, 6}}
      else
        base_datetime
      end
    end
  end

  # timestamp 96: 12 bytes (32-bit nanoseconds + 64-bit seconds)
  def decode_timestamp(<<nanoseconds::unsigned-32, unix_seconds::signed-64>>) do
    if nanoseconds > 999_999_999 do
      throw({:error, :invalid_timestamp})
    else
      gregorian_seconds = unix_seconds + @epoch_offset
      erlang_datetime = :calendar.gregorian_seconds_to_datetime(gregorian_seconds)
      base_datetime = NaiveDateTime.from_erl!(erlang_datetime)

      if nanoseconds > 0 do
        microseconds = div(nanoseconds, 1000)
        %{base_datetime | microsecond: {microseconds, 6}}
      else
        base_datetime
      end
    end
  end

  def check_byte_size(size, max_size) when size > max_size do
    throw({:error, {:max_byte_size_exceeded, max_size}})
  end

  def check_byte_size(_size, _max_size), do: :ok

  def check_depth(depth, max_depth) when depth >= max_depth do
    throw({:error, {:max_depth_reached, max_depth}})
  end

  def check_depth(_depth, _max_depth), do: :ok
end
