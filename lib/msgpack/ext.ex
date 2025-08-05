defmodule Msgpack.Ext do
  @moduledoc """
  Defines a struct to represent MessagePack Custom Extension Types.
  """

  @type t :: %__MODULE__{type: integer, data: binary}
  defstruct [:type, :data]
end
