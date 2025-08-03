defmodule Msgpack.Encoder do
  @moduledoc """
  Handles the logic of encoding Elixir terms into iodata.
  """

  @spec encode(term(), keyword()) :: {:ok, iodata()} | {:error, term()}
  def encode(term, opts) do
    do_encode(term, opts)
  end

  defp do_encode(nil, _opts), do: {:ok, <<0xc0>>}
  defp do_encode(true, _opts), do: {:ok, <<0xc3>>}
  defp do_encode(false, _opts), do: {:ok, <<0xc2>>}

  defp do_encode(int, _opts) when is_integer(int) and int >= 0 and int < 128 do
    {:ok, <<int>>}
  end

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

  defp do_encode(string, _opts) when is_binary(string) do
    size = byte_size(string)
    {:ok, [encode_string_header(size), string]}
  end

  defp do_encode(list, opts) when is_list(list) do
    results = Enum.map(list, &do_encode(&1, opts))

    with {:ok, encoded_elements} <- sequence(results) do
      size = length(list)
      {:ok, [encode_array_header(size), encoded_elements]}
    end
  end

  defp do_encode(tuple, opts) when is_tuple(tuple) do
    do_encode(Tuple.to_list(tuple), opts)
  end

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

  defp encode_array_header(size) when size < 16, do: <<0x90 + size>>
  defp encode_array_header(size) when size < 65_536, do: <<0xdc, size::16>>
  defp encode_array_header(size) when size < 4_294_967_296, do: <<0xdd, size::32>>

  defp encode_map_header(size) when size < 16, do: <<0x80 + size>>
  defp encode_map_header(size) when size < 65_536, do: <<0xde, size::16>>
  defp encode_map_header(size) when size < 4_294_967_296, do: <<0xdf, size::32>>
end
