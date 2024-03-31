//// Gleam utilities for parsing, comparing, and encoding SemVer versions.
////
//// This package aims to respect the specifications of the Semantic
//// Versioning 2.0.0 standard as described at https://semver.org

import gleam/int
import gleam/list
import gleam/string


/// SemVer holds the constituent parts of a SemVer 2.0.0 definition
/// as defined at: https://semver.org
pub type SemVer {
    SemVer(
        major: Int,
        minor: Int,
        patch: Int,
        pre: String,
        build: String)
}

/// Constant representing an empty SemVer (`0.0.0` with no pre/build tags).
pub const empty_semver = SemVer(0, 0, 0, "", "")

/// Prefix for errors on failing to split an integer while parsing.
pub const integer_split_failure_error_prefix = "Failed to split integer from string: "
/// Prefix for errors on failing to parse an integer value from a split.
pub const integer_parse_failure_error_prefix = "Failed to parse integer value from string: "
/// Prefix for errors on missing pre-release/build tag separator after core part.
pub const no_post_core_separator_error_prefix =
"Expected '-' or '+' as a separator between the core part of
 the SemVer string and the rest of it: "

/// Parses the given string into a `SemVer`.
/// Parsing rules are based on the grammar defined at: https://semver.org
pub fn parse(version: String) -> Result(SemVer, String) {
    case consume_core_semver(version) {
        Ok(#(#(major, minor, patch), rest)) -> {
            let split_pre_build = case rest {
                "" -> Ok(#("", ""))
                // Rest has no pre-release fields:
                "+" <> build -> Ok(#("", build))
                "-" <> rest2  -> Ok(split_pre_release_and_build(rest2))
                _ -> Error(no_post_core_separator_error_prefix <> rest)
            }
            case split_pre_build {
                // TODO(aznashwan): validate pre and build format
                Ok(#(pre, build)) -> {
                    Ok(SemVer(major, minor, patch, pre, build))
                }
                Error(e) -> Error(e)
            }
        }
        Error(e) -> Error(e)
    }
}

// Consumes and converts one positive integer from the given string.
fn consume_int_up_to_char(str: String, char: String) -> Result(#(Int, String), String) {
    case string.split_once(str, on: char) {
        Ok(#(intstr, rest)) -> {
            case int.parse(intstr) {
                Ok(int) -> Ok(#(int, rest))
                Error(_) -> Error(integer_parse_failure_error_prefix <> intstr)
            }
        }
        Error(_) -> case int.parse(str) {
            Ok(int) -> Ok(#(int, ""))
            Error(_) -> Error(integer_split_failure_error_prefix <> str)
        }
    }
}

// Consumes the leading core SemVer definition from the given string.
fn consume_core_semver(str: String) ->
        Result(#(#(Int, Int, Int), String), String) {
    case consume_int_up_to_char(str, ".") {
        Ok(#(major, rest1)) -> {
            case consume_int_up_to_char(rest1, ".") {
                Ok(#(minor, rest2)) -> {
                    case consume_int_up_to_char(rest2, "-") {
                        Ok(#(patch, rest3)) ->
                            Ok(#(#(major, minor, patch), "-" <> rest3))
                        Error(_) -> case consume_int_up_to_char(rest2, "+") {
                            Ok(#(patch, rest3)) ->
                                Ok(#(#(major, minor, patch), "+" <> rest3))
                            Error(e) -> Error(e)
                        }
                    }
                }
                Error(e) -> Error(e)
            }
        }
        Error(e) -> Error(e)
    }
}

// Splits the pre-release and build.
fn split_pre_release_and_build(from str: String) -> #(String, String) {
    case string.split_once(str, "+") {
        Ok(#(pre, build)) -> #(pre, build)
        Error(_) -> #(str, "")
    }
}

/// Converts a `SemVer` back into a `String`.
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


// const invalid_core_parts_count_error_message =
// "SemVer string has incorrect number of integer elements.
//  Must be of the form: 'Major.Minor.Patch'."
//
// const invalid_core_parts_format_error_message =
// "Invalid number of core parts to SemVer string.
//  Must be formed of 3 positive integers: 'Int1.Int2.Int3'."
//
// const negative_core_parts_error_message =
// "Non-positive elements in SemVer string.
//  All SemVer parts must be integers greater or equal to 0."

// const codepoint_a = 65
// const codepoint_z = 90
// const codepoint_a_up = 97
// const codepoint_z_up = 122
// const codepoint_zero = 48
// const condepoint_nine = 57
//
// fn is_alnum_codepoint(codepoint: Int) -> Bool {
//     { codepoint >= codepoint_zero && codepoint <= condepoint_nine}
//     || { codepoint >= codepoint_a && codepoint <= codepoint_z }
//     || { codepoint >= codepoint_a_up && codepoint <= codepoint_z_up }
// }
//
// fn is_alnum_str(str: String) -> Bool {
//     str
//     |> string.to_utf_codepoints
//     |> list.map(string.utf_codepoint_to_int)
//     |> list.all(is_alnum_codepoint)
// }
//
// fn parse_semver_core(from version: String) -> Result(#(Int, Int, Int), String) {
//     case string.split(version, on: ".") {
//         [_major, _minor, _patch] as split -> {
//             case split |> list.map(int.parse) |> result.all {
//                 Ok(ints) -> case ints
//                                  |> list.map(is_positive_semver_part)
//                                  |> result.all {
//                     Ok([min, maj, pat]) -> Ok(#(min, maj, pat))
//                     Error(m) -> Error(m)
//                     Ok(_) -> Error("This error should never be possible.")
//                 }
//                 Error(_) -> Error(invalid_core_parts_format_error_message)
//             }
//         }
//         _ -> Error(invalid_core_parts_count_error_message)
//     }
// }
//
// fn is_positive_semver_part(int: Int) -> Result(Int, String) {
//     case int >= 0 {
//         True -> Ok(int)
//         False -> Error(negative_core_parts_error_message)
//     }
// }
