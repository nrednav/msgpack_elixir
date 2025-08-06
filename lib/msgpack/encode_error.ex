defmodule Msgpack.EncodeError do
  @moduledoc """
  Error raised when an unsupported Elixir term is passed to `Msgpack.encode!/2`.

  This error is raised for terms that have no corresponding representation in
  the MessagePack specification, such as PIDs, references, or functions.
  """
  defexception [:message]
end
