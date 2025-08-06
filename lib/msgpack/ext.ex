defmodule Msgpack.Ext do
  @moduledoc """
  Represents a MessagePack custom extension type.

  The MessagePack specification allows for custom, application-specific types
  to be encoded. This struct is the Elixir representation for such types.
  It consists of an integer `type` tag (from -128 to 127) and a binary `data`
  payload.

  The `type` of `-1` is reserved for the MessagePack Timestamp extension and is
  handled automatically by this library for `DateTime` and `NaiveDateTime`
  structs.

  ## Example

  Encoding and decoding a custom type for a complex number.

  ```elixir
  # Let's say an application uses type `74` for complex numbers.
  # The payload is the real part followed by the imaginary part, as floats.
  iex> complex_number = %Msgpack.Ext{type: 74, data: <<3.14::float, 1.59::float>>}
  iex> {:ok, encoded} = Msgpack.encode(complex_number)
  iex> Msgpack.decode(encoded)
  {:ok, %Msgpack.Ext{type: 74, data: <<3.14::float, 1.59::float>>}}
  ```
  """

  @typedoc "A MessagePack extension type, with an integer type and a binary payload."
  @type t :: %__MODULE__{type: integer, data: binary}
  defstruct [:type, :data]
end
