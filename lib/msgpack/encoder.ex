defmodule Msgpack.Encoder do
  alias Msgpack.UnsupportedAtomError

  @spec encode(term(), keyword()) :: {:ok, binary()} | {:error, {:unsupported_type, term()}}
  def encode(term, opts) do
    do_encode(term, opts) |> IO.iodata_to_binary()
  end

  defp do_encode(nil, _opts), do: <<0xc0>>
  defp do_encode(true, _opts), do: <<0xc3>>
  defp do_encode(false, _opts), do: <<0xc2>>
  defp do_encode(int, _opts) when is_integer(int) and int >= 0 and int < 128, do: <<int>>

  defp do_encode(atom, opts) when is_atom(atom) do
    case Keyword.get(opts, :atoms, :string) do
      :string ->
        do_encode(Atom.to_string(atom), opts)
      :error ->
        raise %UnsupportedAtomError{atom: atom}
      _ ->
        raise %ArgumentError{message: "invalid value for :atoms option"}
    end
  end

  defp do_encode(string, _opts) when is_binary(string) do
    size = byte_size(string)
    [encode_string_header(size), string]
  end

  defp do_encode(list, opts) when is_list(list) do
    size = length(list)
    encoded_elements = Enum.map(list, &do_encode(&1, opts))
    [encode_array_header(size), encoded_elements]
  end

  defp do_encode(tuple, opts) when is_tuple(tuple), do: do_encode(Tuple.to_list(tuple), opts)

  defp do_encode(map, opts) when is_map(map) do
    size = map_size(map)

    encoded_pairs =
      Enum.map(map, fn {key, value} ->
        [do_encode(key, opts), do_encode(value, opts)]
      end)

    [encode_map_header(size), encoded_pairs]
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
