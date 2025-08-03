defmodule Msgpack.DecodeError do
  defexception [:message, :reason]

  @impl true
  def message(exception) do
    "Failed to decode MessagePack binary. Reason = #{inspect(exception.reason)}"
  end
end
