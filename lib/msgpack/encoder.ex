defmodule Msgpack.Encoder do
  @moduledoc """
  Handles the logic of encoding Elixir terms into iodata.
  """

  @spec encode(term(), keyword()) :: {:ok, iodata()} | {:error, term()}
  def encode(term, opts) do
    do_encode(term, opts)
  end

  defp do_encode(nil, _opts), do: {:ok, <<0xc0>>}

  # ==== Boolean ====
  defp do_encode(true, _opts), do: {:ok, <<0xc3>>}
  defp do_encode(false, _opts), do: {:ok, <<0xc2>>}

  # ==== Integers ====
  defp do_encode(int, _opts) when is_integer(int) do
    encoded_int =
      cond do
        int >= 0 and int < 128 -> <<int>>
        int >= -32 and int < 0 -> <<int::signed-8>>
        int >= 0 and int < 256 -> <<0xcc, int::8>>
        int >= -128 and int < 128 -> <<0xd0, int::signed-8>>
        int >= 0 and int < 65_536 -> <<0xcd, int::16>>
        int >= -32_768 and int < 32_768 -> <<0xd1, int::signed-16>>
        int >= 0 and int < 4_294_967_296 -> <<0xce, int::32>>
        int >= -2_147_483_648 and int < 2_147_483_648 -> <<0xd2, int::signed-32>>
        true -> <<0xd3, int::signed-64>>
      end

    {:ok, encoded_int}
  end

  # ==== Floats ====
  defp do_encode(float, _opts) when is_float(float) do
    {:ok, <<0xcb, float::float-64>>}
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
  defp do_encode(binary, _opts) when is_binary(binary) do
    size = byte_size(binary)

    encoded_binary =
      if String.valid?(binary) do
        [encode_string_header(size), binary]
      else
        [encode_binary_header(size), binary]
      end

    {:ok, encoded_binary}
  end

  # ==== Lists ====
  defp do_encode(list, opts) when is_list(list) do
    results = Enum.map(list, &do_encode(&1, opts))

    with {:ok, encoded_elements} <- sequence(results) do
      size = length(list)
      {:ok, [encode_array_header(size), encoded_elements]}
    end
  end

  # ==== Tuples ====
  defp do_encode(tuple, opts) when is_tuple(tuple) do
    do_encode(Tuple.to_list(tuple), opts)
  end

  # ==== Maps ====
  defp do_encode(map, opts) when is_map(map) do
    results =
      Enum.map(map, fn {key, value} ->
        with {:ok, encoded_key} <- do_encode(key, opts),
             {:ok, encoded_value} <- do_encode(value, opts) do
          {:ok, [encoded_key, encoded_value]}
        end
      end)

    with {:ok, encoded_pairs} <- sequence(results) do
      size = map_size(map)
      {:ok, [encode_map_header(size), encoded_pairs]}
    end
  end

  # ==== Unsupported Terms ====
  defp do_encode(unsupported_term, _opts) do
    {:error, {:unsupported_type, unsupported_term}}
  end

  # ==== Helpers ====

  # Takes a list of `{:ok, val}` or `{:error, reason}` tuples.
  # Returns `{:ok, [vals]}` if all are successful, otherwise returns
  # the first `{:error, reason}` encountered.
  defp sequence(list_of_results) do
    case Enum.find(list_of_results, &match?({:error, _}, &1)) do
      nil ->
        values = Enum.map(list_of_results, fn {:ok, value} -> value end)
        {:ok, values}

      error_tuple ->
        error_tuple
    end
  end

  defp encode_string_header(size) when size < 32, do: <<0xa0 + size>>
  defp encode_string_header(size) when size < 256, do: <<0xd9, size::8>>
  defp encode_string_header(size) when size < 65_536, do: <<0xda, size::16>>
  defp encode_string_header(size) when size < 4_294_967_296, do: <<0xdb, size::32>>

  defp encode_binary_header(size) when size < 256, do: <<0xc4, size::8>>
  defp encode_binary_header(size) when size < 65_536, do: <<0xc5, size::16>>
  defp encode_binary_header(size) when size < 4_294_967_296, do: <<0xc6, size::32>>

  defp encode_array_header(size) when size < 16, do: <<0x90 + size>>
  defp encode_array_header(size) when size < 65_536, do: <<0xdc, size::16>>
  defp encode_array_header(size) when size < 4_294_967_296, do: <<0xdd, size::32>>

  defp encode_map_header(size) when size < 16, do: <<0x80 + size>>
  defp encode_map_header(size) when size < 65_536, do: <<0xde, size::16>>
  defp encode_map_header(size) when size < 4_294_967_296, do: <<0xdf, size::32>>
end
