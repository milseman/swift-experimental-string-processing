
import _RegexParser

import XCTest
import _StringProcessing
import RegexBuilder


private let statement = """
CREDIT    03/02/2022    Payroll from employer      $200.23
CREDIT    03/03/2022    Sanctioned Individual A    $2,000,000.00
DEBIT     03/03/2022    Totally Legit Shell Corp   $2,000,000.00
DEBIT     03/05/2022    Beanie Babies Are Back     $57.33
DEBIT     06/03/2022    Oxford Comma Supply Depot  £57.33
"""

private func process(_ transaction: String) throws {
  var slice = transaction[...]

  // Extract a field, advancing `slice` to the start of the next field
  func extractField() -> Substring {
    let endIdx = {
      var start = slice.startIndex
      while true {
        // Position of next whitespace (including tabs)
        guard let spaceIdx = slice[start...].firstIndex(where: \.isWhitespace) else {
          return slice.endIndex
        }

        // Tab suffices
        if slice[spaceIdx] == "\t" {
          return spaceIdx
        }

        // Otherwise check for a second whitespace character
        let afterSpaceIdx = slice.index(after: spaceIdx)
        if afterSpaceIdx == slice.endIndex || slice[afterSpaceIdx].isWhitespace {
          return spaceIdx
        }

        // Skip over the single space and try again
        start = afterSpaceIdx
      }
    }()
    defer { slice = slice[endIdx...].drop(while: \.isWhitespace) }
    return slice[..<endIdx]
  }

  let kind = extractField()
  let date = try Date(
    String(extractField()), strategy:  Date.FormatStyle(date: .numeric))
  let account = extractField()
  let amount = try Decimal(
    String(extractField()), format: .currency(code: "USD"))

  print(kind, date, account, amount)
}

extension RegexDSLTests {
  func testProcessUsingIndices() throws {
    for line in statement.split(separator: "\n") {
      try process(String(line))
    }
  }
}

