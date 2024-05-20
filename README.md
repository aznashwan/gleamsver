# gleamsver

Comprehensive set of native Gleam utilities for handling
[SemVer 2.0.0](https://semver.org) version strings.

[![Package Version](https://img.shields.io/hexpm/v/gleamsver)](https://hex.pm/packages/gleamsver)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gleamsver/)

```sh
gleam add gleamsver
```

```gleam
import gleam/io
import gleamsver

fn compress_message(message: String) -> String {
  message <> ", but compressed ;)"
}

pub fn main() {
  // Parse correct SemVer 2.0.0 strings using `parse()`:
  let assert Ok(server_version_with_compression) = gleamsver.parse("1.3.7-rc0")
  io.debug(server_version_with_compression)  // SemVer(1, 3, 7, "rc0", "")

  // Parse loose SemVer strings using `parse_loosely()`:
  let assert Ok(current_server_version) = gleamsver.parse_loosely("v1.4")

  // Convert back to SemVer strings using `to_string()`:
  let uncompressed_message =
    "Hello, server version " <> gleamsver.to_string(current_server_version)

  let message = {
    // Guard against version mismatches using `guard_version_*()` functions:
    use <- gleamsver.guard_version_compatible(
      version: server_version_with_compression,
      compatible_with: current_server_version,
      else_return: uncompressed_message,
    )

    // Compression will only occur if the above guard succeeds:
    compress_message(uncompressed_message)
  }

  // Prints "Hello, server version 1.4.0, but compressed ;)"
  io.println(message)
}
```

Further documentation can be found at <https://hexdocs.pm/gleamsver>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
gleam shell # Run an Erlang shell
```
