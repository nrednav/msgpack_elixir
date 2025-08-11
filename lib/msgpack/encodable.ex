defprotocol Msgpack.Encodable do
  @moduledoc """
  A protocol for converting custom Elixir structs into a Msgpack-encodable
  format.

  This protocol provides a hook into the `Msgpack.encode/2` function, allowing
  developers to define custom serialization logic for their structs.

  ## Contract

  An implementation of `encode/1` for a struct must return a basic Elixir term
  that the Msgpack library can encode directly. This includes:
  - Maps (with string, integer, or atom keys that will be converted to strings)
  - Lists
  - Strings or Binaries
  - Integers
  - Floats
  - Booleans
  - `nil`

  It is important that the returned term **must not** contain other custom
  structs that themselves require an `Encodable` implementation. The purpose of
  this protocol is to perform a single-level transformation from a custom struct
  into a directly encodable term. Returning a nested custom struct will result
  in an `{:error, {:unsupported_type, term}}` during encoding.

  ## Example

  ```elixir
  defimpl Msgpack.Encodable, for: User do
    def encode(%User{id: id, name: name}) do
      # Transform the User struct into a map, which is directly encodable.
      {:ok, %{"id" => id, "name" => name}}
    end
  end
  ```
  """

  @doc """
  Receives a custom struct and must return `{:ok, term}` or `{:error, reason}`.

  The `term` in a successful result must be a directly encodable Elixir type.
  """
  @spec encode(struct()) :: {:ok, term()} | {:error, any()}
  def encode(struct)
end
