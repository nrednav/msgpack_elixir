# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
