// Copyright (C) 2024 Nashwan Azhari
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

//// Gleam utilities for parsing, comparing, and encoding SemVer versions.
////
//// This package aims to respect the specifications of the Semantic
//// Versioning 2.0.0 standard as described at https://semver.org.

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

/// Constant representing an empty SemVer (`0.0.0` with no pre/build tags).
pub const empty_semver = SemVer(0, 0, 0, "", "")

/// Parses the given string into a `SemVer`.
///
/// Parsing rules are EXACTLY based on the rules defined on [semver.org](https://semver.org).
/// If you would prefer some leniency when parsing, see `parse_loosely()`.
///
/// See `SemVerParseError` for possible error variants returned by `parse()`.
///
/// ## Examples
///
/// ```gleam
/// parse("1.2.3-rc0+20240505")
/// // -> Ok(SemVer(major: 1, minor; 2, patch: 3, pre: "rc0", build: "20240505"))
/// ```
///
/// Both the Pre-release ("-rc0") and Build ("+20240505") parts are optional:
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
/// The `parse()` function aims to return a relevant error variant and
/// accompanying helpful String message on parsing failures.
///
/// Please see `type SemVerParseError` and `string_from_parsing_error()`.
///
/// ```gleam
/// parse("abc")
/// -> MissingMajor("Leading Major SemVer Integer part is missing.")
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

/// Parse the given string into a `SemVer` more loosely than `parse()`.
///
/// Please see `parse()` for a baseline on how this function works, as
/// all inputs accepted by `parse()` are also accepted by `parse_loosely()`.
///
/// The main additions over the behavior of `parse()` are as follows:
/// * will also accept a single leading 'v' in the input (e.g. "v1.2.3-pre+build")
/// * will accept missing Minor and/or Patch versions (e.g. "1-pre+build")
/// * will accept *any* non-alphanumeric character in the Pre-release and Build
///   parts as long as they are still prefixed by the usual '-' or '+'.
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

/// Converts a `SemVer` into a `String` as defined on [semver.org](https://semver.org).
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

/// Converts a `SemVer` into a `String` as defined on: [semver.org](https://semver.org).
/// Will omit the `Minor.Patch` (second and third parts) if they are `0`.
///
/// Although its output will **not** be re-parseable using `parse()`,
/// it is still compatible with `parse_loosely()`.
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

/// Compares **only** the core `Major.Minor.Patch` versions of the two given
/// `SemVer`s, returning the `gleam/order.Order` of the resulting comparisons.
///
/// It does **not** compare the Pre-release or Build tags in any way!
/// If you want to check for exact equality, use `are_equal()`.
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

/// Compares **only** the core `Major.Minor.Patch` of the two given `SemVer`s,
/// returning `True` only if they are exactly equal.
///
/// If you would like an exact equality check of the Pre-release and Build
/// parts as well, please use `are_equal()`.
///
/// ## Examples
///
/// ```gleams
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
/// of the two given `SemVer`s, returning `True` only if they are exactly equal.
///
/// ## Examples
///
/// ```gleams
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
        order.Eq -> case #(v1.pre == v2.pre, v1.build == v2.build) {
            #(True, True) -> True
            _ -> False
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

/// Type whose variants can possibly be returned by `parse()` on invalid
/// inputs, and a subset of them can be returned by `parse_loosely()`.
///
/// To get the error string from within it, simply use `the_error.msg`,
/// or call `string_from_parsing_error(the_error)`.
///
pub type SemVerParseError {
    /// Returned only by `parse()` when its input is empty.
    EmptyInput(msg: String)

    /// Returned when the Major part of a SemVer is missing.
    /// I.e. there are no leading numeric digits to the input String.
    MissingMajor(msg: String)
    /// Returned only by `parse()` when the Minor part of a SemVer is missing.
    /// I.e. when there is no Minor part like "1..3" or "1-pre+build".
    MissingMinor(msg: String)
    /// Returned only by `parse()` when the Patch part of a SemVer is missing.
    /// I.e. when there is no Patch part like "1.2.+build" or "1.2-pre+build".
    MissingPatch(msg: String)
    /// Returned only by `parse()` when the Pre-release part of a SemVer is
    /// missing despite it having its leading hyphen present.
    /// E.g: "1.2.3-" or "1.2.3-+build".
    MissingPreRelease(msg: String)
    // Returned only by `parse()` when the Build part of a SemVer
    // is missing despite it having its leading plus present.
    // E.g: "1.2.3+" or "1.2.3-rc0+".
    MissingBuild(msg: String)

    /// Returned when there is no Pre-release or Build separators ('-' and '+')
    /// between the Major.Minor.Patch core part of the SemVer and the rest.
    /// E.g: "1.2.3rc0" or "1.2.3build5".
    MissingPreOrBuildSeparator(msg: String)

    /// Returned when the Major part of a SemVer is malformed.
    InvalidMajor(msg: String)
    /// Returned when the Minor part of a SemVer is malformed.
    InvalidMinor(msg: String)
    /// Returned when the Patch part of a SemVer is malformed.
    InvalidPatch(msg: String)
    /// Returned when the Pre-release tags part of a SemVer is malformed.
    /// This includes when it is empty ("1.2.3-+build"), or has invalid chars.
    InvalidPreRelease(msg: String)
    /// Returned when the Build tags part of a SemVer is malformed.
    /// This includes when it is empty ("1.2.3-pre+"), or has invalid chars.
    InvalidBuild(msg: String)

    /// Internal UTF conversion error which you should NEVER get.
    InternalCodePointError(msg: String)
    /// Internal error variant only used for testing which you should NEVER get.
    InternalError(msg: String)
}

/// Returns the inner String from any `SemVerParseError` type variant.
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
            Ok(#(pre, build)) -> case #(pre, build) {
                #(pre, post) -> case strict {
                    False -> Ok(#(pre, post))
                    True -> case #(
                            validate_pre_and_build_chars(pre),
                            validate_pre_and_build_chars(build)) {
                        #(Ok(pre), Ok(build)) -> Ok(#(pre, build))
                        #(Error(e), _) -> Error(
                            InvalidPreRelease(
                                "Pre-release part " <> quote(pre)
                                <> " is invalid: " <> e))
                        #(_, Error(e)) -> Error(
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
