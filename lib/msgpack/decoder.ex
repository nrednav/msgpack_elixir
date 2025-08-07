defmodule Msgpack.Decoder do
  @moduledoc """
  Handles the logic of decoding a MessagePack binary into an Elixir term.
  """

  alias Msgpack.Decoder.Internal

  @spec decode(binary(), keyword()) :: {:ok, term()} | {:error, term()}
  def decode(binary, opts \\ []) do
    merged_opts = Keyword.merge(default_options(), opts)

    try do
      case Internal.decode(binary, merged_opts) do
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

  @doc """
  Returns a keyword list of the default options for the decoder.
  """
  def default_options() do
    [
      max_depth: 100,
      max_byte_size: 10_000_000 # 10MB
    ]
  end
end
