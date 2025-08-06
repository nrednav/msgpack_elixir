# Telemetry

This library emits `:telemetry` events for all `encode/2` and `decode/2`
operations. This allows you to integrate `Msgpack` into your application's
monitoring and observability stack.

This guide will show you how to attach a simple logger to these events.

## 1. Define a Telemetry Handler

First, define a module that will receive and handle the events. This handler can
log the event, increment a metric, or record a trace span.

```elixir
defmodule MyTelemetryHandler do
  require Logger

  def attach do
    :telemetry.attach_many(
      "msgpack-logger",
      [
        [:msgpack, :encode, :start],
        [:msgpack, :encode, :stop],
        [:msgpack, :encode, :exception],
        [:msgpack, :decode, :start],
        [:msgpack, :decode, :stop],
        [:msgpack, :decode, :exception]
      ],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event(event_name, measurements, metadata, _config) do
    Logger.info("Telemetry Event: #{inspect(event_name)}",
      measurements: measurements,
      metadata: metadata
    )
  end
end
```

## 2. Attach the Handler

Attach the handler when your application starts, for example, in your
`Application.start/2` callback.

```elixir
# In your application.ex
def start(_type, _args) do
  # ... other startup code
  MyTelemetryHandler.attach()
  # ...
end
```

## Understanding Events

The library emits standard `:start`, `:stop`, and `:exception` events for each operation.

### Encoding Events

#### `[:msgpack, :encode, :start]`

  - **Dispatched Before:** The encoding process begins.
  - **`measurements`:** `%{system_time: ...}`
  - **`metadata`:** `%{opts: keyword(), term: term()}`

#### `[:msgpack, :encode, :stop]`

- **Dispatched After:** The encoding process finishes (either successfully or with a logical error).
- **`measurements`:** `%{duration: native_time}`
- **`metadata`:**
  - **On success:** `%{outcome: :ok, byte_size: non_neg_integer()}`
  - **On logical failure:** `%{outcome: :error}`

#### `[:msgpack, :encode, :exception]`

  - **Dispatched If:** An error occurs during encoding.
  - **`measurements`:** `%{duration: native_time}`
  - **`metadata`:** `%{kind: :error | :throw | :exit, reason: term(), stacktrace: list()}`

### Decoding Events

#### `[:msgpack, :decode, :start]`

  - **Dispatched Before:** The decoding process begins.
  - **`measurements`:** `%{system_time: ...}`
  - **`metadata`:** `%{opts: keyword(), byte_size: non_neg_integer()}`

#### `[:msgpack, :decode, :stop]`

- **Dispatched After:** The decoding process finishes (either successfully or with a logical error).
- **`measurements`:** `%{duration: native_time}`
- **`metadata`:**
  - **On success:** `%{outcome: :ok}`
  - **On logical failure:** `%{outcome: :error}`

#### `[:msgpack, :decode, :exception]`

  - **Dispatched If:** An error occurs during decoding.
  - **`measurements`:** `%{duration: native_time}`
  - **`metadata`:** `%{kind: :error | :throw | :exit, reason: term(), stacktrace: list()}`
