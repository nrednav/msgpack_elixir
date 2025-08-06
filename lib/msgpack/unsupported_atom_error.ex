defmodule Msgpack.UnsupportedAtomError do
  @moduledoc """
  Error raised by `Msgpack.encode!/2` when an atom is encountered and the
  `:atoms` option is set to `:error`.

  This provides a strategy for ensuring that atoms, an Elixir-specific type,
  are not unintentionally leaked into a serialization format intended for
  cross-language interoperability.
  """
  defexception [:atom]

  @impl true
  def message(exception) do
    "Cannot encode atom #{inspect(exception.atom)} when `atoms: :error` option is set."
  end
end
