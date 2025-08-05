defmodule Msgpack.DecodeError do
  defexception [:message, :reason]

  @impl true
  def message(%{reason: :unexpected_eof}) do
    "Unexpected end of file. The MessagePack binary is incomplete."
  end

  def message(%{reason: {:unknown_prefix, prefix}}) do
    "Unknown type prefix: #{prefix}. The byte `0x#{Integer.to_string(prefix, 16)}` is not a valid MessagePack type marker."
  end

  def message(%{reason: {:trailing_bytes, rest}}) do
    "Trailing bytes remaining after decoding. A valid MessagePack binary must have exactly one root object. Remaining data: #{inspect(rest)}"
  end

  def message(%{reason: {:max_depth_reached, max_depth}}) do
    "Maximum nesting depth of #{max_depth} reached. This limit can be configured with the `:max_depth` option."
  end

  def message(%{reason: {:max_byte_size_exceeded, max_size}}) do
    "A declared object size exceeds the maximum of #{max_size} bytes. This limit can be configured with the `:max_byte_size` option."
  end

  def message(%{reason: :invalid_timestamp}) do
    "Invalid timestamp format. The nanosecond field must be less than 1,000,000,000."
  end

  def message(exception) do
    "Failed to decode MessagePack binary. Reason = #{inspect(exception.reason)}"
  end
end
