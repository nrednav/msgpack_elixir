defmodule Msgpack.Encoder do
  @moduledoc """
  Handles the logic of encoding Elixir terms into iodata.
  """

  @spec encode(term(), keyword()) :: {:ok, iodata()} | {:error, term()}
  def encode(term, opts \\ []) do
    merged_opts = Keyword.merge(default_opts(), opts)
    do_encode(term, merged_opts)
  end

  @doc """
  Returns a keyword list of the default options for the encoder.
  """
  def default_opts() do
    [
      atoms: :string,
      string_validation: true
    ]
  end

  # ==== Nil ====
  defp do_encode(nil, _opts), do: {:ok, <<0xC0>>}

  # ==== Boolean ====
  defp do_encode(true, _opts), do: {:ok, <<0xC3>>}
  defp do_encode(false, _opts), do: {:ok, <<0xC2>>}

  # ==== Integers ====
  defp do_encode(int, _opts) when is_integer(int) do
    if int < -9_223_372_036_854_775_808 or int > 18_446_744_073_709_551_615 do
      {:error, {:unsupported_type, int}}
    else
      encoded_int =
        cond do
          int >= 0 and int < 128 -> <<int>>
          int >= -32 and int < 0 -> <<int::signed-8>>
          int >= 0 and int < 256 -> <<0xCC, int::8>>
          int >= -128 and int < 128 -> <<0xD0, int::signed-8>>
          int >= 0 and int < 65_536 -> <<0xCD, int::16>>
          int >= -32_768 and int < 32_768 -> <<0xD1, int::signed-16>>
          int >= 0 and int < 4_294_967_296 -> <<0xCE, int::32>>
          int >= -2_147_483_648 and int < 2_147_483_648 -> <<0xD2, int::signed-32>>
          int >= 0 and int < 18_446_744_073_709_551_616 -> <<0xCF, int::unsigned-64>>
          true -> <<0xD3, int::signed-64>>
        end

      {:ok, encoded_int}
    end
  end

  # ==== Floats ====
  defp do_encode(float, _opts) when is_float(float) do
    <<decoded_as_32bit::float-32>> = <<float::float-32>>

    if decoded_as_32bit == float do
      {:ok, <<0xCA, float::float-32>>}
    else
      {:ok, <<0xCB, float::float-64>>}
    end
  end

  # ==== Atoms ====
  defp do_encode(atom, opts) when is_atom(atom) do
    case Keyword.get(opts, :atoms, :string) do
      :string ->
        do_encode(Atom.to_string(atom), opts)

      :error ->
        {:error, {:unsupported_atom, atom}}

      other ->
        raise ArgumentError, "invalid value for :atoms option: #{inspect(other)}"
    end
  end

  # ==== Binaries (String + Raw) ====
  defp do_encode(binary, opts) when is_binary(binary) do
    size = byte_size(binary)

    validate_string = Keyword.get(opts, :string_validation, true)

    encoded_binary =
      if validate_string do
        if String.valid?(binary) do
          [encode_string_header(size), binary]
        else
          [encode_binary_header(size), binary]
        end
      else
        [encode_string_header(size), binary]
      end

    {:ok, encoded_binary}
  end

  # ==== Structs (DateTime, NaiveDateTime and Ext) ====
  defp do_encode(%DateTime{} = datetime, opts) do
    case DateTime.shift_zone(datetime, "Etc/UTC") do
      {:ok, utc_datetime} ->
        utc_datetime
        |> DateTime.to_naive()
        |> do_encode(opts)

      {:error, _reason} ->
        {:error, {:unsupported_type, datetime}}
    end
  end

  defp do_encode(%NaiveDateTime{} = datetime, _opts) do
    {:ok, encode_timestamp(datetime)}
  end

  defp do_encode(%Msgpack.Ext{type: type, data: data}, _opts) do
    size = byte_size(data)

    header =
      cond do
        size == 1 -> <<0xD4, type::signed-8>>
        size == 2 -> <<0xD5, type::signed-8>>
        size == 4 -> <<0xD6, type::signed-8>>
        size == 8 -> <<0xD7, type::signed-8>>
        size == 16 -> <<0xD8, type::signed-8>>
        size < 256 -> <<0xC7, size::8, type::signed-8>>
        size < 65_536 -> <<0xC8, size::16, type::signed-8>>
        true -> <<0xC9, size::32, type::signed-8>>
      end

    {:ok, [header, data]}
  end

  # ==== Lists ====
  defp do_encode(list, opts) when is_list(list) do
    acc = {:ok, []}

    reducer = fn element, {:ok, acc_list} ->
      case do_encode(element, opts) do
        {:ok, encoded_element} ->
          {:ok, [encoded_element | acc_list]}

        error ->
          {:error, error}
      end
    end

    case Enum.reduce(list, acc, reducer) do
      {:ok, encoded_elements} ->
        size = length(list)
        {:ok, [encode_array_header(size), Enum.reverse(encoded_elements)]}

      {:error, error} ->
        error
    end
  end

  # ==== Tuples ====
  defp do_encode(tuple, opts) when is_tuple(tuple) do
    do_encode(Tuple.to_list(tuple), opts)
  end

  # ==== Maps ====
  defp do_encode(map, opts) when is_map(map) do
    acc = {:ok, []}

    reducer = fn {key, value}, {:ok, acc_list} ->
      with {:ok, encoded_key} <- do_encode(key, opts),
           {:ok, encoded_value} <- do_encode(value, opts) do
        {:ok, [[encoded_key, encoded_value] | acc_list]}
      else
        error ->
          {:error, error}
      end
    end

    case Enum.reduce(map, acc, reducer) do
      {:ok, encoded_pairs} ->
        size = map_size(map)
        {:ok, [encode_map_header(size), Enum.reverse(encoded_pairs)]}

      {:error, error} ->
        error
    end
  end

  # ==== Unsupported Terms ====
  defp do_encode(unsupported_term, _opts) do
    {:error, {:unsupported_type, unsupported_term}}
  end

  # ==== Helpers ====
  defp encode_string_header(size) when size < 32, do: <<0xA0 + size>>
  defp encode_string_header(size) when size < 256, do: <<0xD9, size::8>>
  defp encode_string_header(size) when size < 65_536, do: <<0xDA, size::16>>
  defp encode_string_header(size) when size < 4_294_967_296, do: <<0xDB, size::32>>

  defp encode_binary_header(size) when size < 256, do: <<0xC4, size::8>>
  defp encode_binary_header(size) when size < 65_536, do: <<0xC5, size::16>>
  defp encode_binary_header(size) when size < 4_294_967_296, do: <<0xC6, size::32>>

  defp encode_array_header(size) when size < 16, do: <<0x90 + size>>
  defp encode_array_header(size) when size < 65_536, do: <<0xDC, size::16>>
  defp encode_array_header(size) when size < 4_294_967_296, do: <<0xDD, size::32>>

  defp encode_map_header(size) when size < 16, do: <<0x80 + size>>
  defp encode_map_header(size) when size < 65_536, do: <<0xDE, size::16>>
  defp encode_map_header(size) when size < 4_294_967_296, do: <<0xDF, size::32>>

  defp encode_timestamp(datetime) do
    seconds = NaiveDateTime.diff(datetime, ~N[1970-01-01 00:00:00], :second)
    nanoseconds = elem(datetime.microsecond, 0) * 1000

    cond do
      # Timestamp 32: nanoseconds are 0 and seconds fit in 32 bits
      nanoseconds == 0 and seconds >= 0 and seconds <= 0xFFFFFFFF ->
        [<<0xD6, -1::signed-8>>, <<seconds::unsigned-32>>]

      # Timestamp 64: seconds fit in 34 bits
      seconds >= 0 and seconds < 0x400000000 ->
        data = Bitwise.bor(Bitwise.bsl(nanoseconds, 34), seconds)
        [<<0xD7, -1::signed-8>>, <<data::64>>]

      # Timestamp 96: fallback for all other dates (pre-epoch or far-future)
      true ->
        [<<0xC7, 12, -1::signed-8>>, <<nanoseconds::32, seconds::signed-64>>]
    end
  end
end
