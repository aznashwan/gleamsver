
import gleam/io

import gleam/list
import gleam/result
import gleam/string

import gleeunit
import gleeunit/should

import gleamsver.{type SemVer, SemVer}


const positive_testcases = [
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
        "1.2.3-pre-1-2-3+build-4-5-6",
        SemVer(1, 2, 3, "pre-1-2-3", "build-4-5-6")
    ),
]

pub fn parse_positive_test() {
    let testfn = fn(testcase) {
        let #(input, expected) = testcase
        input
        |> gleamsver.parse
        |> result.unwrap(gleamsver.empty_semver)
        |> should.equal(expected)
    }
    list.map(positive_testcases, testfn)
}

pub fn to_string_test() {
    let testfn = fn(testcase) {
        let #(input, expected) = testcase
        expected
        |> gleamsver.to_string
        |> should.equal(input)
    }
    list.map(positive_testcases, testfn)
}

pub fn to_string_parse_symmetry_test() {
    let testfn = fn(testcase) {
        let #(stringver, _) = testcase
        stringver
        |> gleamsver.parse
        |> result.unwrap(gleamsver.empty_semver)
        |> gleamsver.to_string
        |> should.equal(stringver)
    }
    list.map(positive_testcases, testfn)
}

const negative_parse_testcases = [
    #(
        "",
        gleamsver.integer_split_failure_error_prefix,
    ),
    #(
        "1",
        gleamsver.integer_split_failure_error_prefix,
    ),
    #(
        "1.2",
        gleamsver.integer_split_failure_error_prefix,
    ),
    #(
        "abc",
        gleamsver.integer_split_failure_error_prefix,
    ),
    #(
        "1.abc",
        gleamsver.integer_split_failure_error_prefix,
    ),
    #(
        "a.b.c",
        gleamsver.integer_parse_failure_error_prefix,
    ),
    #(
        "1.2.abc",
        gleamsver.integer_split_failure_error_prefix,
    ),
    #(
        "1.2.3NOSEP",
        gleamsver.integer_split_failure_error_prefix,
    ),
    // TODO(aznashwan): fix these tests:
    #(
        "1.2.3-",
        gleamsver.no_post_core_separator_error_prefix,
    ),
    #(
        "1.2.3+",
        gleamsver.no_post_core_separator_error_prefix,
    ),
]

pub fn parse_negative_test() {
    let testfn = fn(testcase) {
        let #(input, expected_error_prefix) = testcase

        input
        |> gleamsver.parse
        |> io.debug
        |> result.unwrap_error(or: "Expected error prefix: " <> expected_error_prefix)
        |> io.debug
        |> string.starts_with(expected_error_prefix)
        |> should.equal(True)
    }
    list.map(negative_parse_testcases, testfn)
}

pub fn main() {
    gleeunit.main()
}
