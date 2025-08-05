defmodule Msgpack.Decoder do
  @moduledoc """
  Handles the logic of decoding a MessagePack binary into an Elixir term.
  """

  @default_max_depth 100
  @default_max_byte_size 10_000_000 # 10MB

  # The number of gregorian seconds from year 0 to the Unix epoch. This is a constant.
  @epoch_offset :calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})

  @spec decode(binary(), keyword()) :: {:ok, term()} | {:error, term()}
  def decode(binary, opts \\ []) do
    merged_opts =
      opts
      |> Keyword.put_new(:max_depth, @default_max_depth)
      |> Keyword.put_new(:max_byte_size, @default_max_byte_size)

    try do
      case do_decode(binary, merged_opts) do
        {:ok, {term, <<>>}} ->
          {:ok, term}

        {:ok, {_term, rest}} ->
          {:error, {:trailing_bytes, rest}}

        {:error, reason} ->
          {:error, reason}
      end
    catch
      {:error, reason} ->
        {:error, reason}
    end
  end

  # ==== Nil ====
  defp do_decode(<<0xC0, rest::binary>>, _opts), do: {:ok, {nil, rest}}

  # ==== Boolean ====
  defp do_decode(<<0xC3, rest::binary>>, _opts), do: {:ok, {true, rest}}
  defp do_decode(<<0xC2, rest::binary>>, _opts), do: {:ok, {false, rest}}

  # ==== Integers ====
  # ==== Positive Fixint ====
  defp do_decode(<<int::8, rest::binary>>, _opts) when int < 128 do
    {:ok, {int, rest}}
  end

  # ==== Negative Fixint ====
  defp do_decode(<<int::signed-8, rest::binary>>, _opts) when int >= -32 and int < 0 do
    {:ok, {int, rest}}
  end

  # ==== Unsigned Integers ====
  defp do_decode(<<0xCC, int::8, rest::binary>>, _opts), do: {:ok, {int, rest}}
  defp do_decode(<<0xCD, int::16, rest::binary>>, _opts), do: {:ok, {int, rest}}
  defp do_decode(<<0xCE, int::32, rest::binary>>, _opts), do: {:ok, {int, rest}}
  defp do_decode(<<0xCF, int::64, rest::binary>>, _opts), do: {:ok, {int, rest}}

  # ==== Signed Integers ====
  defp do_decode(<<0xD0, int::signed-8, rest::binary>>, _opts), do: {:ok, {int, rest}}
  defp do_decode(<<0xD1, int::signed-16, rest::binary>>, _opts), do: {:ok, {int, rest}}
  defp do_decode(<<0xD2, int::signed-32, rest::binary>>, _opts), do: {:ok, {int, rest}}
  defp do_decode(<<0xD3, int::signed-64, rest::binary>>, _opts), do: {:ok, {int, rest}}

  # ==== Floats ====
  defp do_decode(<<0xCA, float::float-32, rest::binary>>, _opts), do: {:ok, {float, rest}}
  defp do_decode(<<0xCB, float::float-64, rest::binary>>, _opts), do: {:ok, {float, rest}}

  # ==== Strings ====
  defp do_decode(<<prefix, rest::binary>>, opts) when prefix >= 0xA0 and prefix <= 0xBF do
    size = prefix - 0xA0
    decode_string(rest, size, opts)
  end

  defp do_decode(<<0xD9, size::8, rest::binary>>, opts), do: decode_string(rest, size, opts)
  defp do_decode(<<0xDA, size::16, rest::binary>>, opts), do: decode_string(rest, size, opts)
  defp do_decode(<<0xDB, size::32, rest::binary>>, opts), do: decode_string(rest, size, opts)

  # ==== Raw Binary ====
  defp do_decode(<<0xC4, size::8, rest::binary>>, opts), do: decode_binary(rest, size, opts)
  defp do_decode(<<0xC5, size::16, rest::binary>>, opts), do: decode_binary(rest, size, opts)
  defp do_decode(<<0xC6, size::32, rest::binary>>, opts), do: decode_binary(rest, size, opts)

  # ==== Arrays ====
  defp do_decode(<<prefix, rest::binary>>, opts) when prefix >= 0x90 and prefix <= 0x9F do
    size = prefix - 0x90
    decode_array(rest, size, opts)
  end

  defp do_decode(<<0xDC, size::16, rest::binary>>, opts), do: decode_array(rest, size, opts)
  defp do_decode(<<0xDD, size::32, rest::binary>>, opts), do: decode_array(rest, size, opts)

  # ==== Maps ====
  defp do_decode(<<prefix, rest::binary>>, opts) when prefix >= 0x80 and prefix <= 0x8F do
    size = prefix - 0x80
    decode_map(rest, size, opts)
  end

  defp do_decode(<<0xDE, size::16, rest::binary>>, opts), do: decode_map(rest, size, opts)
  defp do_decode(<<0xDF, size::32, rest::binary>>, opts), do: decode_map(rest, size, opts)

  # ==== Extensions & Timestamps ====
  # ==== Fixext ====
  defp do_decode(<<0xD4, type::signed-8, data::binary-size(1), rest::binary>>, opts),
    do: decode_ext(type, data, rest, opts)

  defp do_decode(<<0xD5, type::signed-8, data::binary-size(2), rest::binary>>, opts),
    do: decode_ext(type, data, rest, opts)

  defp do_decode(<<0xD6, type::signed-8, data::binary-size(4), rest::binary>>, opts),
    do: decode_ext(type, data, rest, opts)

  defp do_decode(<<0xD7, type::signed-8, data::binary-size(8), rest::binary>>, opts),
    do: decode_ext(type, data, rest, opts)

  defp do_decode(<<0xD8, type::signed-8, data::binary-size(16), rest::binary>>, opts),
    do: decode_ext(type, data, rest, opts)

  # ==== Ext ====
  defp do_decode(<<0xC7, len::8, type::signed-8, data::binary-size(len), rest::binary>>, opts),
    do: decode_ext(type, data, rest, opts)

  defp do_decode(<<0xC8, len::16, type::signed-8, data::binary-size(len), rest::binary>>, opts),
    do: decode_ext(type, data, rest, opts)

  defp do_decode(<<0xC9, len::32, type::signed-8, data::binary-size(len), rest::binary>>, opts),
    do: decode_ext(type, data, rest, opts)

  # ==== Unknown types ====
  defp do_decode(<<prefix, _rest::binary>>, _opts) do
    {:error, {:unknown_prefix, prefix}}
  end

  defp do_decode(<<>>, _opts) do
    {:error, :unexpected_eof}
  end

  # ==== Helpers ====
  defp decode_string(binary, size, opts) do
    if max_size = opts[:max_byte_size], do: check_byte_size(size, max_size)

    case binary do
      <<string::binary-size(size), rest::binary>> ->
        {:ok, {string, rest}}

      _ ->
        {:error, :unexpected_eof}
    end
  end

  defp decode_binary(binary, size, opts) do
    if max_size = opts[:max_byte_size], do: check_byte_size(size, max_size)

    case binary do
      <<bin::binary-size(size), rest::binary>> ->
        {:ok, {bin, rest}}

      _ ->
        {:error, :unexpected_eof}
    end
  end

  defp decode_array(binary, size, opts) do
    depth = opts[:depth] || 0

    check_depth(depth, opts[:max_depth])
    check_byte_size(size, opts[:max_byte_size])

    new_opts = Keyword.put(opts, :depth, depth + 1)

    decode_many(binary, size, [], new_opts)
  end

  defp decode_map(binary, size, opts) do
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
  defp decode_many(binary, 0, acc, _opts) do
    {:ok, {Enum.reverse(acc), binary}}
  end

  defp decode_many(binary, count, acc, opts) do
    case do_decode(binary, opts) do
      {:ok, {term, rest}} ->
        decode_many(rest, count - 1, [term | acc], opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode_ext(-1, data, rest, _opts) do
    {:ok, {decode_timestamp(data), rest}}
  end

  defp decode_ext(type, data, rest, _opts) do
    {:ok, {%Msgpack.Ext{type: type, data: data}, rest}}
  end

  # timestamp 32: 4 bytes (32-bit unsigned integer seconds)
  defp decode_timestamp(<<unix_seconds::unsigned-32>>) do
    gregorian_seconds = unix_seconds + @epoch_offset
    erlang_datetime = :calendar.gregorian_seconds_to_datetime(gregorian_seconds)
    NaiveDateTime.from_erl!(erlang_datetime)
  end

  # timestamp 64: 8 bytes (30-bit nanoseconds + 34-bit seconds)
  defp decode_timestamp(<<data::unsigned-64>>) do
    nanoseconds = :erlang.bsr(data, 34)

    if nanoseconds > 999_999_999 do
      throw({:error, :invalid_timestamp})
    else
      unix_seconds = :erlang.band(data, 0x00000003_FFFFFFFF)
      gregorian_seconds = unix_seconds + @epoch_offset
      erlang_datetime = :calendar.gregorian_seconds_to_datetime(gregorian_seconds)
      base_datetime = NaiveDateTime.from_erl!(erlang_datetime)

      if nanoseconds > 0 do
        NaiveDateTime.add(base_datetime, nanoseconds, :nanosecond)
      else
        base_datetime
      end
    end
  end

  # timestamp 96: 12 bytes (32-bit nanoseconds + 64-bit seconds)
  defp decode_timestamp(<<nanoseconds::unsigned-32, unix_seconds::signed-64>>) do
    if nanoseconds > 999_999_999 do
      throw({:error, :invalid_timestamp})
    else
      gregorian_seconds = unix_seconds + @epoch_offset
      erlang_datetime = :calendar.gregorian_seconds_to_datetime(gregorian_seconds)
      base_datetime = NaiveDateTime.from_erl!(erlang_datetime)

      if nanoseconds > 0 do
        NaiveDateTime.add(base_datetime, nanoseconds, :nanosecond)
      else
        base_datetime
      end
    end
  end

  defp check_byte_size(size, max_size) when size > max_size do
    throw({:error, {:max_byte_size_exceeded, max_size}})
  end

  defp check_byte_size(_size, _max_size), do: :ok

  defp check_depth(depth, max_depth) when depth >= max_depth do
    throw({:error, {:max_depth_reached, max_depth}})
  end

  defp check_depth(_depth, _max_depth), do: :ok
end
