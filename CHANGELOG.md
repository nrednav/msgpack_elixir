# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v2.0.0] - 2025-08-10

### Changed

- **BREAKING:** Map encoding is now deterministic by default
  - `Msgpack.encode/2` sorts map keys according to Elixir's standard term
    ordering before serialization
  - This guarantees that identical maps produce identical binary output, but it
    alters the output compared to previous versions of this library

### Added

- Added a `:deterministic` option to `Msgpack.encode/2`
  - You can set this to `false` to disable key sorting for higher performance in
    contexts where deterministic output is not required.
- Added the `Msgpack.Encodable` protocol to allow for custom serialization logic
  for any Elixir struct
  - This allows users to encode their own data types, such as %Product{} or
    %User{}, directly

## [v1.1.1] - 2025-08-09

### Fixed

- Fixed broken links in documentation

## [v1.1.0] - 2025-08-09

### Added

- Added a new Streaming API that processes data in chunks, reducing peak memory
  usage when handling large datasets or network streams
  - Introduced `Msgpack.encode_stream/2` to lazily encode a stream of Elixir
    terms one by one
  - Introduced `Msgpack.decode_stream/2` to lazily decode a stream of
    MessagePack objects, capable of handling data that arrives in multiple
    chunks
- Added CI workflow to run tests against supported Elixir versions

### Changed

- Updated minimum supported Elixir version to v1.12
  - While the library may work with older versions, StreamData supports a
    minimum of v1.12, so it would be missing the property tests

### Fixed

- Updated timestamp decoding to be backwards-compatible with Elixir v1.12

## [v1.0.2] - 2025-08-06

### Fixed

- Add missing `guides/` directory to list of published docs in package config

## [v1.0.1] - 2025-08-06

### Added

- Added a dedicated how-to guide for using telemetry

### Changed

- Exception messages were expanded to include specific details about the cause
  of the error and, where applicable, configuration options for resolution.
- Updated all documentation (@moduledoc, @doc, readme, etc.)

## [v1.0.0] - 2025-08-02

### Added

- Initial release
- Support for all MessagePack types, including `Integer`, `Float`, `String`,
  `Binary`, `Array`, `Map`, `Ext`, and the `Timestamp` extension
  - Encoding for the full 64-bit unsigned integer range
- Native encoding and decoding for Elixir's `DateTime` and `NaiveDateTime`
  structs
- Protection against maliciously crafted decoding inputs via `:max_depth` and
  `:max_byte_size` options
- Added a `:string_validation` option to `encode/2` to bypass UTF-8 validation
  for performance gains
- Emits `:telemetry` events for all encode and decode operations
- Includes `encode!/2` and `decode!/2` for raising exceptions on errors
