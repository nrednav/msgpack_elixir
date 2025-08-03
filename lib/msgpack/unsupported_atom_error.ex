defmodule Msgpack.UnsupportedAtomError do
  defexception [:atom]

  @impl true
  def message(exception) do
    "cannot encode atom #{inspect(exception.atom)} when `atoms: :error` option is set."
  end
end
