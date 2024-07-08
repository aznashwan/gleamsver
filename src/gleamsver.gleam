// Copyright (C) 2024 Nashwan Azhari
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

//// Gleam utilities for parsing, comparing, and encoding SemVer versions.
////
//// This package aims to respect the specifications of the Semantic
//// Versioning 2.0.0 standard as described on [semver.org](https://semver.org).
////
//// ```gleam
//// import gleam/io
//// import gleamsver
////
//// fn compress_message(message: String) -> String {
////   message <> ", but compressed ;)"
//// }
////
//// pub fn main() {
////   // Parse correct SemVer 2.0.0 strings using `parse()`:
////   let assert Ok(server_version_with_compression) = gleamsver.parse("1.3.7-rc0")
////   io.debug(server_version_with_compression)  // SemVer(1, 3, 7, "rc0", "")
////
////   // Parse loose SemVer strings using `parse_loosely()`:
////   let assert Ok(current_server_version) = gleamsver.parse_loosely("v1.4")
////
////   // Convert back to SemVer strings using `to_string()`:
////   let uncompressed_message =
////     "Hello, server version " <> gleamsver.to_string(current_server_version)
////
////   let message = {
////     // Guard against version mismatches using `guard_version_*()` functions:
////     use <- gleamsver.guard_version_compatible(
////       version: server_version_with_compression,
////       compatible_with: current_server_version,
////       else_return: uncompressed_message,
////     )
////
////     // Compression will only occur if the above guard succeeds:
////     compress_message(uncompressed_message)
////   }
////
////   // Prints "Hello, server version 1.4.0, but compressed ;)"
////   io.println(message)
//// }
//// ```

import gleam/int
import gleam/list
import gleam/order
import gleam/result
import gleam/string


/// SemVer represents all the constituent parts of a Semantic Versioning
/// (or SemVer) 2.0.0 definition as described on [semver.org](https://semver.org).
pub type SemVer {
    SemVer(
        /// Leading Major Integer version.
        major: Int,
        /// Middle Minor Integer version.
        minor: Int,
        /// Third Patch Integer version.
        patch: Int,
        /// String Pre-build tag(s) of the version.
        pre: String,
        /// String Build tag(s) of the version.
        build: String)
}

/// Constant representing an empty SemVer
/// (`0.0.0` with no pre-release or build tags).
pub const empty_semver = SemVer(0, 0, 0, "", "")

/// Parses the given string into a [`SemVer`](#SemVer).
///
/// Parsing rules are **exactly** based on the rules defined on [semver.org](https://semver.org).
///
/// If you would prefer some leniency when parsing, see [`parse_loosely`](#parse_loosely).
///
/// See [`SemVerParseError`](#SemVerParseError) for possible error variants
/// returned by [`parse`](#parse).
///
/// ## Examples
///
/// ```gleam
/// parse("1.2.3-rc0+20240505")
/// // -> Ok(SemVer(major: 1, minor; 2, patch: 3, pre: "rc0", build: "20240505"))
/// ```
///
/// Both the Pre-release (`-rc0`) and Build (`+20240505`) parts are optional:
///
/// ```gleam
/// parse("4.5.6-rc0")
/// // -> Ok(SemVer(major: 4, minor; 5, patch: 6, pre: "rc0", build: ""))
///
/// parse("4.5.6+20240505")
/// // -> Ok(SemVer(major: 4, minor; 5, patch: 6, pre: "", build: "20240505"))
///
/// parse("4.5.6-rc0+20240505")
/// // -> Ok(SemVer(major: 4, minor; 5, patch: 6, pre: "rc0", build: "20240505"))
///
/// // NOTE: the Pre-release should always come *before* the Build,
/// // otherwise, it will get included as part of the Build:
/// parse("6.7.8+20240505-rc0")
/// // -> Ok(SemVer(major: 4, minor; 5, patch: 6, pre: "", build: "20240505-rc0"))
/// ```
///
/// ## Possible parsing errors
///
/// The [`parse`](#parse) function aims to return a relevant error variant
/// and  accompanying helpful `String` message on parsing failures.
///
/// Please see [`type SemVerParseError`](#SemVerParseError) and
/// [`string_from_parsing_error`](#string_from_parsing_error).
///
/// ```gleam
/// parse("abc")
/// // -> MissingMajor("Leading Major SemVer Integer part is missing.")
/// // To get the error String directly, simply:
/// parse("abc") |> result.map_error(string_from_parsing_error)
/// // -> Error("Leading Major SemVer Integer part is missing.")
/// ```
///
pub fn parse(version: String) -> Result(SemVer, SemVerParseError) {
    case version {
        "" -> Error(EmptyInput("Input SemVer string is empty."))
        _ -> version |> split_by_codepoints |> process_split(strict: True)
    }
}

/// Parse the given string into a [`SemVer`](#SemVer) more loosely than
/// [`parse`](#parse).
///
/// Please see [`parse`](#parse) for a baseline on how this function works, as
/// all inputs accepted by [`parse`](#parse) are also accepted by
/// [`parse_loosely`](#parse_loosely).
///
/// The main additions over the behavior of [`parse`](#parse) are as follows:
/// * will also accept a single leading `v` in the input (e.g. `v1.2.3-pre+build`)
/// * will accept missing Minor and/or Patch versions (e.g. `1-pre+build`)
/// * will accept *any* non-alphanumeric character in the Pre-release and Build
///   parts as long as they are still prefixed by the usual `-` or `+`.
///
/// See [`SemVerParseError`](#SemVerParseError) for possible error variants
/// returned by [`parse_loosely`](#parse_loosely).
///
/// ## Examples
///
/// ```gleam
/// parse_loosely("")
/// // -> Ok(SemVer(major: 0, minor; 0, patch: 0, pre: "", build: ""))
/// ```
///
/// ```gleam
/// parse_loosely("v1-rc0")
/// // -> Ok(SemVer(major: 1, minor; 0, patch: 0, pre: "rc0", build: ""))
/// ```
///
/// ```gleam
/// parse_loosely("v1..3")
/// // -> Ok(SemVer(major: 1, minor; 0, patch: 3, pre: "", build: ""))
/// ```
///
/// ```gleam
/// parse_loosely("v1.2+2024~05~05")
/// // -> Ok(SemVer(major: 1, minor; 2, patch: 0, pre: "", build: "v1.2+2024~05~05"))
/// ```
///
pub fn parse_loosely(version: String) -> Result(SemVer, SemVerParseError) {
    case version {
        "" | "v" -> Ok(empty_semver)
        "v" <> rest -> rest |> split_by_codepoints |> process_split(strict: False)
        version -> version |> split_by_codepoints |> process_split(strict: False)
    }
}

/// Converts a [`SemVer`](#SemVer) into a `String` as defined on
/// [semver.org](https://semver.org).
///
/// ## Examples
///
/// ```gleam
/// to_string(SemVer(1, 2, 3, "rc0", "20240505"))
/// // -> "1.2.3-rc0+20240505"
/// ````
///
/// Both the Pre-release ("-rc0") and Build ("+20240505") parts are optional:
///
/// ```gleam
/// to_string(SemVer(1, 2, 3, "rc0", ""))
/// // -> "1.2.3-rc0"
/// ````
///
/// ```gleam
/// to_string(SemVer(1, 2, 3, "", "20240505"))
/// // -> "1.2.3+20240505"
/// ````
///
pub fn to_string(ver: SemVer) -> String {
    let core =
        [ver.major, ver.minor, ver.patch]
        |> list.map(int.to_string)
        |> string.join(with: ".")

    let with_pre = case ver.pre {
        "" -> core
        pre -> core <> "-" <> pre
    }

    case ver.build {
        "" -> with_pre
        build -> with_pre <> "+" <> build
    }
}

/// Converts a [`SemVer`](#SemVer) into a `String`
/// as defined on [semver.org](https://semver.org).
/// Will omit the `Minor.Patch` (second and third parts) if they are `0`.
///
/// Although its output will **not** be re-parseable using [`parse`](#parse),
/// it is still compatible with [`parse_loosely`](#parse_loosely).
///
/// ## Examples
///
/// ```gleam
/// to_string_concise(SemVer(1, 0, 0, "rc0", "20240505"))
/// // -> "1-rc0+20240505"
/// ````
///
/// ```gleam
/// to_string_concise(SemVer(1, 2, 0, "rc0", "20240505"))
/// // -> "1.2-rc0+20240505"
/// ````
///
pub fn to_string_concise(ver: SemVer) -> String {
    let core = ver.major |> int.to_string

    let core1 = case ver.minor {
        0 -> core
        _ -> core <> "." <> int.to_string(ver.minor)
    }

    let core2 = case ver.patch {
        0 -> core1
        _ -> case ver.minor {
            0 -> core1 <> ".0." <> int.to_string(ver.patch)
            _ -> core1 <> "." <> int.to_string(ver.patch)
        }
    }

    let with_pre = case ver.pre {
        "" -> core2
        pre -> core2 <> "-" <> pre
    }

    case ver.build {
        "" -> with_pre
        build -> with_pre <> "+" <> build
    }
}


/// Compares the core `Major.Minor.Patch` versions and Pre-release tags of the
/// two given [`SemVer`](#SemVer)s, returning the `gleam/order.Order` of the resulting
/// comparisons as described on [semver.org](https://semver.org/#spec-item-11).
///
/// If you would like to only compare core versions, use
/// [`compare_core`](#compare_core).
///
/// If you want to check for exact equality, use [`are_equal`](#are_equal).
///
/// Build tag(s) are **never** compared.
///
/// ## Examples:
///
/// ```gleam
/// compare(SemVer(1, 2, 3, "", ""), with: SemVer(5, 6, 7, "", ""))
/// // -> Lt
///
/// compare(SemVer(1, 2, 3, "rc0", ""), with: SemVer(1, 2, 3, "rc0", ""))
/// // -> Eq
///
/// compare(SemVer(5, 6, 7, "rc0", "20240505"), with: SemVer(1, 2, 3, "rc5", "30240505"))
/// // -> Gt
///
/// // NOTE: pre-release tags are compared:
/// compare(SemVer(1, 2, 3, "alpha", ""), with: SemVer(1, 2, 3, "alpha.1", ""))
/// // -> Lt
///
/// compare(SemVer(1, 2, 3, "alpha.12", ""), with: SemVer(1, 2, 3, "alpha.5", ""))
/// // -> Gt
///
/// // NOTE: will **not** compare Build tags at all!
/// compare(SemVer(1, 2, 3, "rc5", "20240505"), with: SemVer(1, 2, 3, "rc5", "30240505"))
/// // -> Eq
/// ```
///
pub fn compare(v1: SemVer, with v2: SemVer) -> order.Order {
    case compare_core(v1, with: v2) {
        order.Eq -> compare_pre_release_strings(v1.pre, with: v2.pre)
        non_equal -> non_equal
    }
}

/// Compares **only** the core `Major.Minor.Patch` versions of the two given
/// [`SemVer`](#SemVer)s, returning the `gleam/order.Order` of the resulting
/// comparisons.
///
/// It does **not** compare the Pre-release or Build tags in any way!
///
/// If you would like to compare Pre-release tags too, use [`compare`](#compare).
///
/// If you want to check for exact equality, use [`are_equal`](#are_equal).
///
/// ## Examples:
///
/// ```gleam
/// compare_core(SemVer(1, 2, 3, "", ""), with: SemVer(5, 6, 7, "", ""))
/// // -> Lt
///
/// compare_core(SemVer(1, 2, 3, "", ""), with: SemVer(1, 2, 3, "", ""))
/// // -> Eq
///
/// compare_core(SemVer(5, 6, 7, "rc0", "20240505"), with: SemVer(1, 2, 3, "rc5", "30240505"))
/// // -> Gt
///
/// // NOTE: will **not** compare Pre-release and Build tags at all!
/// compare_core(SemVer(1, 2, 3, "rc0", "20240505"), with: SemVer(1, 2, 3, "rc5", "30240505"))
/// // -> Eq
/// ```
///
pub fn compare_core(v1: SemVer, with v2: SemVer) -> order.Order {
    case int.compare(v1.major, v2.major) {
        order.Eq -> {
            case int.compare(v1.minor, v2.minor) {
                order.Eq -> int.compare(v1.patch, v2.patch)
                non_equal -> non_equal
            }
        }
        non_equal -> non_equal
    }
}

/// Checks whether the first given [`SemVer`](#SemVer) is compatible with
/// the second based on the
/// [compatibility rules described on semver.org](https://semver.org/#semantic-versioning-specification-semver).
///
/// In order for a version to count as compatible with another, the Major part
/// of the versions must be **exactly equal**, and the Minor, Patch and
/// Pre-release parts of the first must be less than or equal to the second's.
///
/// If you would like to compare versions in general, use [`compare`](#compare)
/// or [compare_core](#compare_core).
///
/// ## Examples
///
/// ```gleam
/// are_compatible(SemVer(1, 2, 3, "", ""), SemVer(1, 2, 4, "", ""))
/// -> True
///
/// are_compatible(SemVer(2, 0, 0, "", ""), SemVer(1, 2, 3, "", ""))
/// -> False
///
/// // NOTE: Any Pre-release tags have lower precedence than full release:
/// are_compatible(SemVer(1, 2, 3, "", ""), SemVer(1, 2, 3, "alpha.1", ""))
/// -> False
///
/// // NOTE: Build tags are **not** compared:
/// are_compatible(SemVer(1, 2, 3, "", "20240505"), SemVer(1, 2, 3, "", ""))
/// -> True
/// ```
///
pub fn are_compatible(v1: SemVer, with v2: SemVer) -> Bool {
    case v1.major == v2.major {
        False -> False
        True -> case compare(v1, with: v2) {
            order.Gt -> False
            _ -> True
        }
    }
}

/// Compares **only** the core `Major.Minor.Patch` of the two given
/// [`SemVer`](#SemVer)s, returning `True` only if they are exactly equal.
///
/// If you would like an exact equality check of the Pre-release and Build
/// parts as well, please use [`are_equal`](#are_equal).
///
/// ## Examples
///
/// ```gleam
/// are_equal_core(SemVer(1, 2, 3, "", ""), with: SemVer(1, 2, 3, "", ""))
/// // -> True
///
/// // NOTE: Pre-release and Build parts are **not** compared!
/// are_equal_core(SemVer(1, 2, 3, "", ""), with: SemVer(1, 2, 3, "rc0", "20250505"))
/// // -> True
///
/// are_equal_core(SemVer(1, 2, 3, "", ""), with: SemVer(4, 5, 6, "", ""))
/// // -> False
/// ```
///
pub fn are_equal_core(v1: SemVer, with v2: SemVer) -> Bool {
    case compare_core(v1, with: v2) {
        order.Eq -> True
        _ -> False
    }
}

/// Compares the core `Major.Minor.Patch` and the Pre-release and Build tags
/// of the two given [`SemVer`](#SemVer)s, returning `True` only if they
/// are exactly equal.
///
/// ## Examples
///
/// ```gleam
/// are_equal(SemVer(1, 2, 3, "rc5", ""), with: SemVer(1, 2, 3, "rc5", ""))
/// // -> True
///
/// // NOTE: Pre-release and Build parts must be exactly equal too!
/// are_equal(SemVer(1, 2, 3, "", ""), with: SemVer(1, 2, 3, "rc0", "20250505"))
/// // -> False
/// ```
///
pub fn are_equal(v1: SemVer, with v2: SemVer) -> Bool {
    case compare_core(v1, with: v2) {
        order.Eq -> case v1.pre == v2.pre, v1.build == v2.build {
            True, True -> True
            _, _ -> False
        }
        _ -> False
    }
}

// Converts int codepoint to Utf, panicking if invalid.
fn force_int_codepoint_to_utf(codepoint: Int) -> UtfCodepoint {
    case codepoint |> string.utf_codepoint {
        Ok(c) -> c
        Error(_) -> panic as {
            "Could not convert UTF codepoint of int: "
            <> int.to_string(codepoint)
        }
    }
}

// Converts list of int codepoints to a String, panicking on invalid ones.
fn force_int_codepoints_to_string(codepoints: List(Int)) -> String {
    codepoints
    |> list.map(force_int_codepoint_to_utf)
    |> string.from_utf_codepoints
}

// Helper to validate the constituent characters of the pre-release/build tags.
fn validate_pre_and_build_chars(str: String) -> Result(String, String) {
    case str
            |> string.to_utf_codepoints
            |> list.map(string.utf_codepoint_to_int)
            |> list.map(is_valid_pre_or_build_codepoint)
            |> result.all {
        Ok(_) -> Ok(str)
        Error(e) -> Error(e)
    }
}

const codepoint_zero = 48
const condepoint_nine = 57
const codepoint_a = 65
const codepoint_z = 90
const codepoint_a_up = 97
const codepoint_z_up = 122
const codepoint_period = 46
const condepoint_hyphen = 45

fn is_digit_codepoint(codepoint: Int) -> Bool {
    codepoint >= codepoint_zero && codepoint <= condepoint_nine
}

fn is_lowercase_letter_codepoint(codepoint: Int) -> Bool {
    codepoint >= codepoint_a && codepoint <= codepoint_z
}

fn is_uppercase_letter_codepoint(codepoint: Int) -> Bool {
    codepoint >= codepoint_a_up && codepoint <= codepoint_z_up
}

// Helper to return an error String if the given Integer UTF codepoint
// is not valid character for the pre-release or build SemVer components.
// Valid chars are digits 0-9, letters a-z and A-Z, '.', and '-'.
fn is_valid_pre_or_build_codepoint(codepoint: Int) -> Result(Int, String) {
    case is_digit_codepoint(codepoint)
        || is_lowercase_letter_codepoint(codepoint)
        || is_uppercase_letter_codepoint(codepoint)
        || { codepoint == codepoint_period || codepoint == condepoint_hyphen } {
        True -> Ok(codepoint)
        False -> Error(
            "the following character is not allowed by the SemVer standard: "
            <> quote(force_int_codepoints_to_string([codepoint])))
    }
}

// Helper to add double quotes around the given string.
fn quote(str: String) -> String {
    "\"" <> str <> "\""
}

// Helper which splits the given SemVer string into the Major, Minor,
// Patch, and Rest based on UTF8 codepoint comparisons.
fn split_by_codepoints(version: String) -> #(String, String, String, String) {
    let utf_codepoints = version |> string.to_utf_codepoints
    let int_codepoints = utf_codepoints |> list.map(string.utf_codepoint_to_int)

    // let codepoint_period = 46
    let #(major, rest1) = int_codepoints |> list.split_while(is_digit_codepoint)
    let #(minor, rest2) = case rest1 {
        [] -> #([], [])
        // 46 = '.'
        [46, ..post_dot] -> post_dot |> list.split_while(is_digit_codepoint)
        no_dot -> #([], no_dot)
    }
    let #(patch, rest3) = case rest2 {
        [] -> #([], [])
        // 46 = '.'
        [46, ..post_dot] -> post_dot |> list.split_while(is_digit_codepoint)
        no_dot -> #([], no_dot)
    }

    #(
        force_int_codepoints_to_string(major),
        force_int_codepoints_to_string(minor),
        force_int_codepoints_to_string(patch),
        force_int_codepoints_to_string(rest3)
    )
}

/// Type whose variants can possibly be returned by [`parse`](#parse) on invalid
/// inputs, and a subset of them can be returned by [`parse_loosely`](#parse_loosely).
///
/// To get the error string from within it, simply use `the_error.msg`,
/// or call [`string_from_parsing_error(the_error)`](#string_from_parsing_error).
///
pub type SemVerParseError {
    /// Returned only by [`parse`](#parse) when its input is empty.
    EmptyInput(msg: String)

    /// Returned when the Major part of a [`SemVer`](#SemVer) is missing.
    /// I.e. there are no leading numeric digits to the input String.
    MissingMajor(msg: String)
    /// Returned only by [`parse`](#parse) when the Minor part of a [`SemVer`](#SemVer) is missing.
    /// I.e. when there is no Minor part like `1..3` or `1-pre+build`.
    MissingMinor(msg: String)
    /// Returned only by [`parse`](#parse) when the Patch part of a [`SemVer`](#SemVer) is missing.
    /// I.e. when there is no Patch part like `1.2.+build` or `1.2-pre+build`.
    MissingPatch(msg: String)
    /// Returned only by [`parse`](#parse) when the Pre-release part of a [`SemVer`](#SemVer)
    /// is missing despite it having its leading hyphen present.
    /// E.g: `1.2.3-` or `1.2.3-+build`.
    MissingPreRelease(msg: String)
    /// Returned only by [`parse`](#parse) when the Build part of a [`SemVer`](#SemVer)
    /// is missing despite it having its leading plus present.
    /// E.g: `1.2.3+` or `1.2.3-rc0+`.
    MissingBuild(msg: String)

    /// Returned when there is no Pre-release or Build separators (`-` and `+`)
    /// between the Major.Minor.Patch core part of the [`SemVer`](#SemVer) and the rest.
    /// E.g: `1.2.3rc0` or `1.2.3build5`.
    MissingPreOrBuildSeparator(msg: String)

    /// Returned when the Integer Major part of a [`SemVer`](#SemVer) cannot be parsed.
    InvalidMajor(msg: String)
    /// Returned when the Integer Minor part of a [`SemVer`](#SemVer) cannot be parsed.
    InvalidMinor(msg: String)
    /// Returned when the Integer Patch part of a [`SemVer`](#SemVer) cannot be parsed.
    InvalidPatch(msg: String)
    /// Returned only by [`parse`](#parse) when the Pre-release tag part
    /// of a [`SemVer`](#SemVer) contains unacceptable characters.
    InvalidPreRelease(msg: String)
    /// Returned only by [`parse`](#parse) when the Build tag part
    /// of a [`SemVer`](#SemVer) contains unacceptable characters.
    InvalidBuild(msg: String)

    /// Internal UTF conversion error which you should **never** get.
    InternalCodePointError(msg: String)
    /// Internal error variant only used for testing which you should **never** get.
    InternalError(msg: String)
}

/// Returns the inner `String` from any [`SemVerParseError`](#SemVerParseError) type variant.
///
/// This is equivalent to simply using `the_error.msg`.
///
/// ## Examples
///
/// ```gleam
/// string_from_parsing_error(EmptyInput("Input SemVer string is empty."))
/// // -> "Input SemVer string is empty."
/// ```
///
pub fn string_from_parsing_error(error: SemVerParseError) -> String {
    error.msg
}

// Processes Int string version, defaulting empty strings to 0.
fn parse_int_version(intstr: String) -> Result(Int, String) {
    case intstr {
        "" -> Ok(0)
        _ -> case int.parse(intstr) {
            Ok(num) -> case num >= 0 {
                True -> Ok(num)
                False -> Error("Integer SemVer components must be postivie. Got: " <> intstr)
            }
            Error(_) -> Error(
                "Failed to parse integer value from string: " <> intstr)
        }
    }
}

// Helper to process the '-$PRE_RELEASE+$BUILD' parts of a SemVer.
fn process_pre_release_and_build(
        pre_and_build: String,
        strict strict: Bool)
        -> Result(#(String, String), SemVerParseError) {
    case pre_and_build {
        "" -> Ok(#("", ""))
        // Pre-release is missing, only had build:
        "+" <> rest -> case rest {
            // Build missing after '+' (e.g. "1.2.3+").
            "" if strict -> Error(
                MissingBuild(
                    "Build part missing after trailing '+' from: "
                    <> quote(pre_and_build)))
            build if strict -> case validate_pre_and_build_chars(build) {
                Ok(_) -> Ok(#("", rest))
                Error(e) -> Error(
                    InvalidBuild(
                        "Build part " <> quote(build)
                        <> " is invalid: " <> e))
            }
            _ -> Ok(#("", rest))
        }
        "-" <> rest -> case string.split_once(rest, "+") {
            // Pre-release missing after '-' (e.g. "1.2.3-+build")
            Ok(#("", _)) if strict -> Error(
                MissingPreRelease(
                    "Pre-release part missing after leading '-' from: "
                    <> quote(pre_and_build)))
            // Build missing after '+' (e.g. "1.2.3-pre+").
            Ok(#(_, "")) if strict -> Error(
                MissingBuild(
                    "Build part missing after trailing '+' from: "
                    <> quote(pre_and_build)))
            Ok(#(pre, build)) -> case pre, build {
                pre, post -> case strict {
                    False -> Ok(#(pre, post))
                    True -> case validate_pre_and_build_chars(pre),
                            validate_pre_and_build_chars(build) {
                        Ok(pre), Ok(build) -> Ok(#(pre, build))
                        Error(e), _ -> Error(
                            InvalidPreRelease(
                                "Pre-release part " <> quote(pre)
                                <> " is invalid: " <> e))
                        _, Error(e) -> Error(
                            InvalidBuild(
                                "Build part " <> quote(build)
                                <> " is invalid: " <> e))
                    }
                }
            }
            // Cover missing pre-release after hyphen (e.g. "1.2.3-")
            Error(_) if strict && rest == "" -> Error(
                MissingPreRelease(
                    "Pre-release part missing after leading '-' from: "
                    <> quote(pre_and_build)))
            // `string.split()` will only fail if there's no '+',
            // so everything is just the the pre-realse info:
            Error(_) if strict -> case validate_pre_and_build_chars(rest) {
                Ok(_) -> Ok(#(rest, ""))
                Error(e) -> Error(
                    InvalidPreRelease(
                        "Pre-release part " <> quote(rest)
                        <> " is invalid: " <> e))
            }
            Error(_) -> Ok(#(rest, ""))
        }
        _ -> Error(MissingPreOrBuildSeparator(
            "Missing '-' or '+' separator between core SemVer part and "
            <> "Pre-release ('-rc5') or Build ('+2024.05.05') parts. "
            <> "Got: " <> quote(pre_and_build)))
    }
}

// Helper function to process the split parts from `split_by_codepoints()`
// into the final results of `parse()` and `parse_loosely()`.
fn process_split(
        parts: #(String, String, String, String),
        strict strict: Bool)
        -> Result(SemVer, SemVerParseError) {
    case parts {
        #("", _min, _pat, _pre_and_build) ->
            Error(MissingMajor("Leading Major SemVer Integer part is missing."))
        #(_, "", _, _) if strict ->
            Error(MissingMinor("Missing Minor (second) SemVer part."))
        #(_, _, "", _) if strict ->
            Error(MissingPatch("Missing Patch (third) SemVer part."))
        #(majstr, minstr, patstr, pre_and_build) -> {
            case [majstr, minstr, patstr] |> list.map(parse_int_version) {
                [Error(e), _, _] -> Error(InvalidMajor(e))
                [_, Error(e), _] -> Error(InvalidMinor(e))
                [_, _, Error(e)] -> Error(InvalidPatch(e))
                [Ok(major), Ok(minor), Ok(patch)] -> {
                    case process_pre_release_and_build(pre_and_build, strict: strict) {
                        Ok(#(pre, build)) -> Ok(SemVer(major, minor, patch, pre, build))
                        Error(e) -> Error(e)
                    }
                }
                _ -> Error(InternalError(
                    "Somehow mapping over 3 elements produced more/less elements."))
            }
        }
    }
}

/// Compares two given pre-release Strings based on the set of
/// rules described in [point 11 of semver.org](https://semver.org/#spec-item-11).
///
/// ## Examples.
///
/// ```gleam
/// // NOTE: empty pre-release tags always count as larger:
/// compare_pre_release_strings("", "any.thing")
/// // -> Gt
///
/// compare_pre_release_strings("any.thing", "")
/// // -> Lt
///
/// // Integer parts are compared as integers:
/// compare_pre_release_strings("12.thing.A", "13.thing.B")
/// // -> Lt
///
/// // Non-integer parts are compared lexicographically:
/// compare_pre_release_strings("12.thing.A", "12.thing.B")
/// // -> Lt
///
/// // NOTE: integer parts always have lower precedence over non-integer ones:
/// compare_pre_release_strings("12.thing.1", "12.thing.rc0")
/// // -> Lt
///
/// // NOTE: 'B' comes before 'a' in the ASCII table:
/// compare_pre_release_strings("12.thing.B", "12.thing.a")
/// // -> Lt
///
/// // NOTE: '0' comes before '6' in the ASCII table:
/// compare_pre_release_strings("rc07", "rc6")
/// // -> Lt
/// ```
///
pub fn compare_pre_release_strings(pre1: String, with pre2: String) -> order.Order {
    case pre1, pre2 {
        "", "" -> order.Eq
        // No pre-release tags always count as higher precedence:
        "", _ -> order.Gt
        _, "" -> order.Lt
        // Split and compare each set of pre-release tags:
        pre1, pre2 -> {
            compare_pre_release_parts(
                string.split(pre1, on: "."),
                string.split(pre2, on: "."))
        }
    }
}

// Helper to compare two lists of pre-release tags.
fn compare_pre_release_parts(parts1: List(String), parts2: List(String)) ->
        order.Order {
    case parts1, parts2 {
        [], [] -> order.Eq
        [], _ -> order.Lt
        _, [] -> order.Gt
        [part1, ..rest1], [part2, ..rest2] ->
                case compare_pre_release_tag(part1, part2) {
            order.Eq -> compare_pre_release_parts(rest1, rest2)
            order -> order
        }
    }
}

// Helper to compare two single pre-release tags.
// Pre-release tag comparisons follow a rather convoluted set of rules
// as described in [point 11 of semver.org](https://semver.org/#spec-item-11).
fn compare_pre_release_tag(tag1: String, tag2: String) -> order.Order {
    case int.parse(tag1), int.parse(tag2) {
        // Non-integer tags are to be compared lexicographically:
        Error(_), Error(_) -> string.compare(tag1, tag2)
        // Integer tags always have lower precedence to strings:
        Ok(_), Error(_) -> order.Lt
        Error(_), Ok(_) -> order.Gt
        // Two int tags are to be compared as integers:
        Ok(int1), Ok(int2) -> int.compare(int1, int2)
    }
}

/// Guards that the given first [`SemVer`](#SemVer) is compatible with
/// the second [`SemVer`](#SemVer), running and returning the result
/// of the `if_compatible` callback function if so,
/// or returning the `else_return` value if not.
///
/// The semantics of the compatibility check are as dictated by the
/// [`are_compatible`](#are_compatible) function.
///
/// ## Examples
///
/// ```gleam
/// let uncompressed_message = "Hello!"
/// let message = {
///   use <- gleamsver.guard_version_compatible(
///     version: server_version_with_compression,
///     compatible_with: current_server_version,
///     else_return: uncompressed_message,
///   )
///
///   // Compression will only occur if the above guard succeeds:
///   uncompressed_message <> ", but compressed ;)"
/// }
/// io.println(message)  // compression depends on version compatibility
/// ```
pub fn guard_version_compatible(
        version v1: SemVer,
        compatible_with v2: SemVer,
        else_return default_value: t,
        if_compatible operation_if_compatible: fn() -> t) -> t {
    case are_compatible(v1, with: v2) {
        True -> operation_if_compatible()
        False -> default_value
    }
}

/// Guards that the given first [`SemVer`](#SemVer) is less than
/// the second [`SemVer`](#SemVer), running and returning the result
/// of the `if_compatible` callback function if so, or
/// returning the `else_return` default value if not.
///
/// The semantics of the comparison check are as dictated by the
/// [`compare`](#compare) function.
///
/// ## Examples
///
/// ```gleam
/// let uncompressed_message = "Hello!"
/// let message = {
///   use <- gleamsver.guard_version_lt(
///     version: server_version_with_compression,
///     less_that: current_server_version,
///     else_return: uncompressed_message,
///   )
///
///   // Compression will only occur if the above guard succeeds:
///   uncompressed_message <> ", but compressed ;)"
/// }
/// io.println(message)  // compression depends on version ordering
/// ```
pub fn guard_version_lt(
        version v1: SemVer,
        less_than v2: SemVer,
        else_return default_value: t,
        if_compatible operation_if_lt: fn() -> t) -> t {
    case compare(v1, v2) {
        order.Lt -> operation_if_lt()
        _ -> default_value
    }
}

/// Guards that the given first [`SemVer`](#SemVer) is less than or equal
/// to the second [`SemVer`](#SemVer), running and returning the result
/// of the `if_compatible` callback function if so, or
/// returning the `else_return` default value if not.
///
/// The semantics of the comparison check are as dictated by the
/// [`compare`](#compare) function.
///
/// ## Examples
///
/// ```gleam
/// let uncompressed_message = "Hello!"
/// let message = {
///   use <- gleamsver.guard_version_lte(
///     version: server_version_with_compression,
///     less_that_or_equal: current_server_version,
///     else_return: uncompressed_message,
///   )
///
///   // Compression will only occur if the above guard succeeds:
///   uncompressed_message <> ", but compressed ;)"
/// }
/// io.println(message)  // compression depends on version ordering
/// ```
pub fn guard_version_lte(
        version v1: SemVer,
        less_than_or_equal v2: SemVer,
        else_return default_value: t,
        if_compatible operation_if_lte: fn() -> t) -> t {
    case compare(v1, v2) {
        order.Lt | order.Eq -> operation_if_lte()
        _ -> default_value
    }
}


/// Guards that the given first [`SemVer`](#SemVer) is equal to
/// the second [`SemVer`](#SemVer), running and returning the
/// result of the `if_compatible` callback function if so, or
/// returning the `else_return` default value if not.
///
/// The semantics of the comparison check are as dictated by the
/// [`compare`](#compare) function.
///
/// ## Examples
///
/// ```gleam
/// let uncompressed_message = "Hello!"
/// let message = {
///   use <- gleamsver.guard_version_eq(
///     version: server_version_with_compression,
///     equal_to: current_server_version,
///     else_return: uncompressed_message,
///   )
///
///   // Compression will only occur if the above guard succeeds:
///   uncompressed_message <> ", but compressed ;)"
/// }
/// io.println(message)  // compression depends on version equality
/// ```
pub fn guard_version_eq(
        version v1: SemVer,
        equal_to v2: SemVer,
        else_return default_value: t,
        if_compatible operation_if_eq: fn() -> t) -> t {
    case compare(v1, v2) {
        order.Eq -> operation_if_eq()
        _ -> default_value
    }
}

/// Guards that the given first [`SemVer`](#SemVer) is greater than
/// the second [`SemVer`](#SemVer), running and returning the result
/// of the `if_compatible` callback function if so, or
/// returning the `else_return` default value if not.
///
/// The semantics of the comparison check are as dictated by the
/// [`compare`](#compare) function.
///
/// ## Examples
///
/// ```gleam
/// let uncompressed_message = "Hello!"
/// let message = {
///   use <- gleamsver.guard_version_gt(
///     version: current_server_version,
///     greater_than: server_version_with_compression,
///     else_return: uncompressed_message,
///   )
///
///   // Compression will only occur if the above guard succeeds:
///   uncompressed_message <> ", but compressed ;)"
/// }
/// io.println(message)  // compression depends on version ordering
/// ```
pub fn guard_version_gt(
        version v1: SemVer,
        greater_than v2: SemVer,
        else_return default_value: t,
        if_compatible operation_if_gt: fn() -> t) -> t {
    case compare(v1, v2) {
        order.Gt -> operation_if_gt()
        _ -> default_value
    }
}

/// Guards that the given first [`SemVer`](#SemVer) is greater than
/// or equal to the second [`SemVer`](#SemVer), running and returning
/// the result of the `if_compatible` callback function if so, or
/// returning the `else_return` default value if not.
///
/// The semantics of the comparison check are as dictated by the
/// [`compare`](#compare) function.
///
/// ## Examples
///
/// ```gleam
/// let uncompressed_message = "Hello!"
/// let message = {
///   use <- gleamsver.guard_version_gte(
///     version: current_server_version,
///     greater_than_or_equal: server_version_with_compression,
///     else_return: uncompressed_message,
///   )
///
///   // Compression will only occur if the above guard succeeds:
///   uncompressed_message <> ", but compressed ;)"
/// }
/// io.println(message)  // compression depends on version ordering
/// ```
pub fn guard_version_gte(
        version v1: SemVer,
        greater_than_or_equal v2: SemVer,
        else_return default_value: t,
        if_compatible operation_if_gte: fn() -> t) -> t {
    case compare(v1, v2) {
        order.Gt | order.Eq -> operation_if_gte()
        _ -> default_value
    }
}
