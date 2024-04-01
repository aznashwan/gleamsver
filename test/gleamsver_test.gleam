// Copyright (C) 2024 Nashwan Azhari
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import gleam/io

import gleam/int
import gleam/list
import gleam/order
import gleam/result

import gleeunit
import gleeunit/should

import gleamsver.{type SemVer, SemVer}


// Testcases with well-defined SemVer versions for the `parse()` function.
const positive_strict_testcases = [
    #(
        "0.0.0",
        gleamsver.empty_semver
    ),
    #(
        "0.0.1",
        SemVer(0, 0, 1, "", "")
    ),
    #(
        "1.0.0",
        SemVer(1, 0, 0, "", "")
    ),
    #(
        "11.22.33",
        SemVer(11, 22, 33, "", "")
    ),
    #(
        "1.2.3-rc3",
        SemVer(1, 2, 3, "rc3", "")
    ),
    #(
        "1.2.3+buildID",
        SemVer(1, 2, 3, "", "buildID")
    ),
    #(
        "1.2.3-rc0+buildID",
        SemVer(1, 2, 3, "rc0", "buildID")
    ),
    #(
        "1.2.3-rc0.12+build1.2.3",
        SemVer(1, 2, 3, "rc0.12", "build1.2.3")
    ),
    #(
        "1.2.3-pre-1.2-3+build-4.5-6",
        SemVer(1, 2, 3, "pre-1.2-3", "build-4.5-6")
    ),
    #(
        // This is, absurdly enough, technically a valid SemVer:
        "1.2.3+-",
        SemVer(1, 2, 3, "", "-")
    )
]

// Tests `parse()` with well-formed SemVer strings against expected results.
pub fn parse_strict_positive_test() {
    let testfn = fn(testcase, idx) {
        let #(input, expected) = testcase

        io.println(
            "Running parse() test #" <> int.to_string(idx)
            <> " on input: '" <> input <> "'")

        input
        |> gleamsver.parse
        |> should.equal(Ok(expected))
    }
    list.index_map(positive_strict_testcases, testfn)
}

// Tests `to_string()` reproduces SemVEr strings againts expected results.
pub fn to_string_strict_test() {
    let testfn = fn(testcase, idx) {
        let #(input, expected) = testcase

        io.println(
            "Running to_string() test #" <> int.to_string(idx)
            <> " on input: '" <> input <> "'")

        expected
        |> gleamsver.to_string
        |> should.equal(input)
    }
    list.index_map(positive_strict_testcases, testfn)
}

// Tests `parse()` that and `to_string()` are symmetrical.
pub fn to_string_parse_symmetry_strict_test() {
    let testfn = fn(testcase, idx) {
        let #(stringver, _) = testcase

        io.println(
            "Running parse()-to_string() symmetry test #" <> int.to_string(idx)
            <> " on input: '" <> stringver <> "'")

        stringver
        |> gleamsver.parse
        |> result.map(gleamsver.to_string)
        |> should.equal(Ok(stringver))
    }
    list.index_map(positive_strict_testcases, testfn)
}

// Testcases for `parse()` to check it produces reasonable error
// strings for a variety of malformed SemVer Strings.
const negative_strict_parse_testcases = [
    #(
        "",
        gleamsver.EmptyInput("Input SemVer string is empty."),
    ),
    #(
        "1",
        gleamsver.MissingMinor("Missing Minor (second) SemVer part."),
    ),
    #(
        "1..3",
        gleamsver.MissingMinor("Missing Minor (second) SemVer part.")
    ),
    #(
        "1.2",
        gleamsver.MissingPatch("Missing Patch (third) SemVer part."),
    ),
    #(
        "abc.2.3",
        gleamsver.MissingMajor("Leading Major SemVer Integer part is missing."),
    ),
    #(
        "a.b.c",
        gleamsver.MissingMajor("Leading Major SemVer Integer part is missing."),
    ),
    #(
        "1.abc",
        gleamsver.MissingMinor("Missing Minor (second) SemVer part."),
    ),
    #(
        "1.2.abc",
        gleamsver.MissingPatch("Missing Patch (third) SemVer part."),
    ),
    #(
        "1.2.-pre",
        gleamsver.MissingPatch("Missing Patch (third) SemVer part."),
    ),
    #(
        "1.2.3NOSEP",
        gleamsver.MissingPreOrBuildSeparator("Missing '-' or '+' separator between core SemVer part and Pre-release ('-rc5') or Build ('+2024.05.05') parts. Got: \"NOSEP\""),
    ),
    #(
        "1.2.3-",
        gleamsver.MissingPreRelease("Pre-release part missing after leading '-' from: \"-\""),
    ),
    #(
        "1.2.3+",
        gleamsver.MissingBuild("Build part missing after trailing '+' from: \"+\""),
    ),
    #(
        "1.2.3-+",
        gleamsver.MissingPreRelease("Pre-release part missing after leading '-' from: \"-+\""),
    ),
    #(
        "1.2.3-$",
        gleamsver.InvalidPreRelease("Pre-release part \"$\" is invalid: the following character is not allowed by the SemVer standard: \"$\""),
    ),
    #(
        "1.2.3-rc$",
        gleamsver.InvalidPreRelease("Pre-release part \"rc$\" is invalid: the following character is not allowed by the SemVer standard: \"$\""),
    ),
    #(
        "1.2.3+$",
        gleamsver.InvalidBuild("Build part \"$\" is invalid: the following character is not allowed by the SemVer standard: \"$\""),
    ),
    #(
        "1.2.3+123$",
        gleamsver.InvalidBuild("Build part \"123$\" is invalid: the following character is not allowed by the SemVer standard: \"$\""),
    ),
    #(
        "1.2.3-rc1+123$",
        gleamsver.InvalidBuild("Build part \"123$\" is invalid: the following character is not allowed by the SemVer standard: \"$\""),
    ),
    #(
        "1.2.3-$+$",
        gleamsver.InvalidPreRelease("Pre-release part \"$\" is invalid: the following character is not allowed by the SemVer standard: \"$\""),
    ),
    #(
        "1.2.3.4",
        gleamsver.MissingPreOrBuildSeparator("Missing '-' or '+' separator between core SemVer part and Pre-release ('-rc5') or Build ('+2024.05.05') parts. Got: \".4\"")
    )
]

// Tests `parse()` returns expected reasonable error messages
// when given malformed error strings.
pub fn parse_strict_negative_test() {
    let testfn = fn(testcase, idx) {
        let #(input, expected_error) = testcase

        io.println(
            "Running parse() strict negative test #" <> int.to_string(idx)
            <> " on input: '" <> input <> "'")
    
        input
        |> gleamsver.parse
        |> should.equal(Error(expected_error))
    }
    list.index_map(negative_strict_parse_testcases, testfn)
}

// Tests `parse_loosely()` with well-formed SemVer strings that work
// with `parse()` too to ensure compatibility.
pub fn parse_loosely_positive_test() {
    let testfn = fn(testcase, idx) {
        let #(input, expected) = testcase

        io.println(
            "Running parse_loosely() valid test #" <> int.to_string(idx)
            <> " on input: " <> input)

        input
        |> gleamsver.parse_loosely
        |> should.equal(Ok(expected))
    }

    // Add leading 'v' to every input and append to testcases:
    positive_strict_testcases
    |> list.map(fn(testcase) {
        let #(input, expected) = testcase
        #("v" <> input, expected)
    })
    |> list.append(positive_strict_testcases, _)
    |> list.index_map(testfn)
}

// Set of testcases of technically invalid SemVer versions
// to test `parse_loosely()` with.
const loose_semver_testcases = [
    #(
        "",
        gleamsver.empty_semver
    ),

    // Partial core SemVer:
    #(
        "0",
        gleamsver.empty_semver,
    ),
    #(
        "1",
        SemVer(1, 0, 0, "", ""),
    ),
    #(
        "1.2",
        SemVer(1, 2, 0, "", ""),
    ),

    // Major and pre/build:
    #(
        "1-pre",
        SemVer(1, 0, 0, "pre", ""),
    ),
    #(
        "1+build",
        SemVer(1, 0, 0, "", "build"),
    ),
    #(
        "1.-pre",
        SemVer(1, 0, 0, "pre", ""),
    ),
    #(
        "1.+build",
        SemVer(1, 0, 0, "", "build"),
    ),
    #(
        "1..-pre",
        SemVer(1, 0, 0, "pre", ""),
    ),
    #(
        "1..+build",
        SemVer(1, 0, 0, "", "build"),
    ),

    // Major.Minor and pre/build:
    #(
        "1.2.-pre",
        SemVer(1, 2, 0, "pre", ""),
    ),
    #(
        "1.2.+build",
        SemVer(1, 2, 0, "", "build"),
    ),
    #(
        "1.2.-pre+build",
        SemVer(1, 2, 0, "pre", "build"),
    ),

    // Major-Pre with empty pre:
    #(
        "1-",
        SemVer(1, 0, 0, "", ""),
    ),
    #(
        "1.-",
        SemVer(1, 0, 0, "", ""),
    ),
    #(
        "1..-",
        SemVer(1, 0, 0, "", ""),
    ),

    // Major+Build with empty build:
    #(
        "1+",
        SemVer(1, 0, 0, "", ""),
    ),
    #(
        "1.+",
        SemVer(1, 0, 0, "", ""),
    ),
    #(
        "1..+",
        SemVer(1, 0, 0, "", ""),
    ),

    // NOTE: Build can contain hyphens:
    #(
        "1+-",
        SemVer(1, 0, 0, "", "-"),
    ),
    #(
        "1.2+-",
        SemVer(1, 2, 0, "", "-"),
    ),
    #(
        "1.2.3+-",
        SemVer(1, 2, 3, "", "-"),
    ),

    // Empty Pre and Build:
    #(
        "1-+",
        SemVer(1, 0, 0, "", ""),
    ),
    #(
        "1.2-+",
        SemVer(1, 2, 0, "", ""),
    ),
    #(
        "1.2+",
        SemVer(1, 2, 0, "", ""),
    ),
    #(
        "1.2.3",
        SemVer(1, 2, 3, "", ""),
    ),
    #(
        "1.2.3+",
        SemVer(1, 2, 3, "", ""),
    ),
    #(
        "1.2.3-",
        SemVer(1, 2, 3, "", ""),
    ),

    // Random chars in Pre/Build:
    #(
        "1-pre$%^+build*()",
        SemVer(1, 0, 0, "pre$%^", "build*()"),
    ),
    #(
        "1-pre$%^+build*()",
        SemVer(1, 0, 0, "pre$%^", "build*()"),
    ),
    #(
        "1.2-pre$%^+build*()",
        SemVer(1, 2, 0, "pre$%^", "build*()"),
    ),
    #(
        "1.2.3-pre$%^+build*()",
        SemVer(1, 2, 3, "pre$%^", "build*()"),
    ),
]

// Tests `parse_loosely()` with well-formed SemVer strings.
pub fn parse_loosely_semi_valid_inputs_test() {
    let testfn = fn(testcase, idx) {
        let #(input, expected) = testcase

        io.println(
            "Running parse_loosely() semi-valid test #" <> int.to_string(idx)
            <> " on input: '" <> input <> "'")

        input
        |> gleamsver.parse_loosely
        |> should.equal(Ok(expected))
    }

    loose_semver_testcases
    // Add leading 'v' to every input and append to testcases:
    |> list.map(fn(testcase) {
        let #(input, expected) = testcase
        #("v" <> input, expected)
    })
    |> list.append(loose_semver_testcases, _)
    |> list.index_map(testfn)
}

// Tests `to_string_concise()` produces versions strings
// which can be re-parsed with with `parse_loosely()`.
pub fn to_string_concise_parse_loosely_symmetry_test() {
    let testfn = fn(testcase, idx) {
        let #(input, expected) = testcase

        io.println(
            "Running to_string_concise() test #" <> int.to_string(idx)
            <> " on input: '" <> input <> "'")

        let assert Ok(parsed) = input |> gleamsver.parse_loosely

        parsed
        |> gleamsver.to_string_concise
        |> gleamsver.parse_loosely
        |> should.equal(Ok(expected))
    }

    positive_strict_testcases
    |> list.append(loose_semver_testcases, _)
    |> list.index_map(testfn)
}

const compare_core_testcases = [
    #(
        SemVer(0, 0, 0, "", ""),
        SemVer(0, 0, 0, "", ""),
        order.Eq,
    ),
    #(
        SemVer(1, 0, 0, "", ""),
        SemVer(1, 0, 0, "", ""),
        order.Eq,
    ),
    #(
        SemVer(1, 2, 0, "", ""),
        SemVer(1, 2, 0, "", ""),
        order.Eq,
    ),
    #(
        SemVer(1, 2, 3, "", ""),
        SemVer(1, 2, 3, "", ""),
        order.Eq,
    ),

    #(
        SemVer(1, 0, 0, "", ""),
        SemVer(0, 0, 0, "", ""),
        order.Gt,
    ),
    #(
        SemVer(1, 1, 0, "", ""),
        SemVer(1, 0, 0, "", ""),
        order.Gt,
    ),
    #(
        SemVer(1, 2, 1, "", ""),
        SemVer(1, 2, 0, "", ""),
        order.Gt,
    ),
    #(
        SemVer(1, 2, 1, "", ""),
        SemVer(1, 2, 0, "rc0", "123"),
        order.Gt,
    ),
    #(
        SemVer(1, 2, 1, "rc0", "123"),
        SemVer(1, 2, 0, "", ""),
        order.Gt,
    ),

    #(
        SemVer(0, 0, 0, "", ""),
        SemVer(1, 0, 0, "", ""),
        order.Lt,
    ),
    #(
        SemVer(1, 0, 0, "", ""),
        SemVer(1, 1, 0, "", ""),
        order.Lt,
    ),
    #(
        SemVer(1, 2, 0, "", ""),
        SemVer(1, 2, 1, "", ""),
        order.Lt,
    ),
    #(
        SemVer(1, 2, 0, "", ""),
        SemVer(1, 2, 1, "", ""),
        order.Lt,
    ),
    #(
        SemVer(1, 2, 0, "rc0", "123"),
        SemVer(1, 2, 1, "", ""),
        order.Lt,
    ),
    #(
        SemVer(1, 2, 0, "", ""),
        SemVer(1, 2, 1, "rc0", "123"),
        order.Lt,
    ),

    #(
        SemVer(1, 0, 0, "123", ""),
        SemVer(1, 0, 0, "456", ""),
        order.Eq,
    ),
    #(
        SemVer(1, 2, 0, "", "123"),
        SemVer(1, 2, 0, "", "456"),
        order.Eq,
    ),
    #(
        SemVer(1, 2, 0, "123", "789"),
        SemVer(1, 2, 0, "456", "123"),
        order.Eq,
    ),
]

pub fn compare_core_test() {
    let testfn = fn(input: #(SemVer, SemVer, order.Order), idx: Int) {
        let #(first, second, result) = input

        io.println(
            "Running compare_core() test #" <> int.to_string(idx) <> " between '"
            <> gleamsver.to_string(first) <> "' and '"
            <> gleamsver.to_string(second) <> "'")

        gleamsver.compare_core(first, with: second)
        |> should.equal(result)
    }

    compare_core_testcases 
    |> list.index_map(testfn)
}

pub fn are_equal_core_test() {
    let testfn = fn(input: #(SemVer, SemVer, order.Order), idx: Int) {
        let #(first, second, result) = input

        io.println(
            "Running are_equal_core() test #" <> int.to_string(idx)
            <> " between '" <> gleamsver.to_string(first) <> "' and '"
            <> gleamsver.to_string(second) <> "'")

        let bool_result = case result {
            order.Eq -> True
            _ -> False
        }

        gleamsver.are_equal_core(first, with: second)
        |> should.equal(bool_result)
    }

    compare_core_testcases 
    |> list.index_map(testfn)
}

const are_equal_special_testcases = [
    #(
        SemVer(1, 2, 3, "a", ""),
        SemVer(1, 2, 3, "", ""),
        False
    ),
    #(
        SemVer(1, 2, 3, "", "a"),
        SemVer(1, 2, 3, "", ""),
        False
    ),
    #(
        SemVer(1, 2, 3, "", ""),
        SemVer(1, 2, 3, "a", ""),
        False
    ),
    #(
        SemVer(1, 2, 3, "", ""),
        SemVer(1, 2, 3, "", "a"),
        False
    ),

    #(
        SemVer(1, 2, 3, "a", ""),
        SemVer(1, 2, 3, "a", ""),
        True
    ),
    #(
        SemVer(1, 2, 3, "", "a"),
        SemVer(1, 2, 3, "", "a"),
        True
    ),

    #(
        SemVer(1, 2, 3, "rc0", "20240505"),
        SemVer(1, 2, 3, "rc0", "20240505"),
        True
    ),
    #(
        SemVer(1, 2, 3, "rc1", "20250505"),
        SemVer(1, 2, 3, "rc0", "20240505"),
        False 
    ),
]

pub fn are_equal_test() {
    let testfn = fn(input: #(SemVer, SemVer, Bool), idx: Int) {
        let #(first, second, result) = input

        io.println(
            "Running are_equal() test #" <> int.to_string(idx)
            <> " between '" <> gleamsver.to_string(first) <> "' and '"
            <> gleamsver.to_string(second) <> "'")

        gleamsver.are_equal(first, with: second)
        |> should.equal(result)
    }

    // Derive testcases from compare's testcases:
    let core_to_equal_test = fn(testcase: #(SemVer, SemVer, order.Order)) {
        let #(first, second, comparison) = testcase
        case comparison {
            order.Eq -> #(first, second, first.pre == second.pre && first.build == second.build)
            _ -> #(first, second, False)
        }
    }

    compare_core_testcases
    |> list.map(core_to_equal_test)
    |> list.append(are_equal_special_testcases)
    |> list.index_map(testfn)

}

pub fn main() {
    gleeunit.main()
}
