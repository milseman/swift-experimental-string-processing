//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import XCTest

@testable import _StringProcessing
@testable import _RegexParser

// TODO: Unit tests for the engine itself. Functional testing
// is handled by regex tests.

final class ByteCodeGenTests: XCTestCase {
  func testPreviouslyPassingCases() throws {
    try _testMatching(
      regex: #"(?<=abc)defg"#,
      matchingTestCases: ["abcdefg"],
      nonMatchingTestCases: ["adefg", "bdefg", "cdefg"]
    )

    try _testMatching(
      regex: #"(?<=as|b|c)defg"#,
      matchingTestCases: ["asdefg", "bdefg", "cdefg"],
      nonMatchingTestCases: ["adefg", "ddefg"]
    )

    try _testMatching(
      regex: #"(?<=USD )\d+?,?\d+"#,
      matchingTestCases: ["USD 100", "USD 70"],
      nonMatchingTestCases: ["JPY 100", "GBP 70"]
    )
  }

  // TODO: Fix reverse matching that butts up against the start
  func testExecutePositiveLookbehind() throws {
    try _testMatching(
      regex: #"(?<=^\d{1,3})abc"#,
      matchingTestCases: ["123abc"],// "12abc", "123abc"],
      nonMatchingTestCases: []//"a123abc", "1234abc"]
    )
//    try _testMatching(
//      regex: #"(?<=\d{1,3}-.{1,3}-\d{1,3})suffix"#,
//      matchingTestCases: ["12-any-3suffix", "123-_+/-789suffix"],
//      nonMatchingTestCases: ["abc-+a-defsuffix", "1234-any-5suffix"]
//    )
  }

  func _testMatching(regex: String, matchingTestCases: [String], nonMatchingTestCases: [String]) throws {
    let sut = try _compileRegex(regex)

    for input in matchingTestCases {
      let result: Regex<Substring>.Match? = try sut.firstMatch(
        input,
        subjectBounds: input.startIndex..<input.endIndex,
        searchBounds: input.startIndex..<input.endIndex,
        graphemeSemantic: true
      )

      let unwrapped = try XCTUnwrap(result, "No match for '\(regex)' found in '\(input)'")
      print(unwrapped.output)
    }

    for input in nonMatchingTestCases {
      let result: Regex<Substring>.Match? = try sut.firstMatch(
        input,
        subjectBounds: input.startIndex..<input.endIndex,
        searchBounds: input.startIndex..<input.endIndex,
        graphemeSemantic: true
      )

      XCTAssertNil(result, "Expected no match for '\(regex)' in '\(input)'")
    }
  }
}
