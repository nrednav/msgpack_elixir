defmodule Msgpack.EncodableTest.User do
  @moduledoc """
  A simple struct used for testing protocol implementations.
  """
  defstruct [:id, :name]
end

defmodule Msgpack.EncodableTest.Product do
  @moduledoc """
  A simple struct with no protocol implementation.
  """
  defstruct [:id]
end

defimpl Msgpack.Encodable, for: Msgpack.EncodableTest.User do
  def encode(%Msgpack.EncodableTest.User{id: id, name: name}) do
    {:ok, %{"id" => id, "name" => name}}
  end
end
