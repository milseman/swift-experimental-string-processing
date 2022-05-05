
import _RegexParser

import XCTest
import _StringProcessing
import RegexBuilder


private let statement = """
CREDIT    03/02/2022    Payroll from employer      $200.23
CREDIT    03/03/2022    Suspect A                  $2,000,000.00
DEBIT     03/03/2022    Ted's Pet Rock Sanctuary   $2,000,000.00
DEBIT     03/05/2022    Doug's Dugout Dogs         $33.27
"""

private let extraStatement = statement + """
DEBIT     06/03/2022    Oxford Comma Supply Ltd.   £57.33
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

  func testFooReplace() {
    var statement = statement

    func pick(_ currency: Substring) -> Locale {
      switch currency {
      case "$": return Locale(identifier: "en_US")
      case "£": return Locale(identifier: "en_GB")
      default: fatalError("We found another one!")
      }
    }

    let regex = try! Regex(#"""
      (?x)
      (?<date>     \d{2} / \d{2} / \d{4})
      (?<middle>   \P{currencySymbol}+)
      (?<currency> \p{currencySymbol})
      """#, as: (Substring, date: Substring, middle: Substring, currency: Substring).self
    )
    // Regex<(Substring, date: Substring, middle: Substring, currency: Substring)>

    statement.replace(regex) { match -> String in
      let strategy = Date.FormatStyle(date: .numeric).locale(pick(match.currency))
      let date = try! Date(String(match.date), strategy: strategy)
      // ISO 8601, it's the only way to be sure
      let newDate = date.formatted(.iso8601.year().month().day())

      return newDate + match.middle + match.currency
    }


    print(statement)

    // TODO: next slide make it possessive-by-default

  }

  func testFooReplace2() {
    var statement = statement

    func pick(_ currency: Substring) -> Locale {
      switch currency {
      case "$": return Locale(identifier: "en_US")
      case "£": return Locale(identifier: "en_GB")
      default: fatalError("We found another one!")
      }
    }

    let regex = try! Regex(#"""
      (?x)
      (?<date>     \d{2} / \d{2} / \d{4})
      (?<middle>   \P{currencySymbol}+)
      (?<currency> \p{currencySymbol})
      """#, as: (Substring, date: Substring, middle: Substring, currency: Substring).self
    )
    // Regex<(Substring, date: Substring, middle: Substring, currency: Substring)>

    statement.replace(regex) { match -> String in
      let strategy = Date.FormatStyle(date: .numeric).locale(pick(match.currency))
      let date = try! Date(String(match.date), strategy: strategy)
      // ISO 8601, it's the only way to be sure
      let newDate = date.formatted(.iso8601.year().month().day())

      return newDate + match.middle + match.currency
    }


    print(statement)

    // TODO: next slide make it possessive-by-default

  }

  func testFooSplit() {
    let transaction = "DEBIT     03/05/2022    Doug's Dugout Dogs         $33.27"

    let fragments = transaction.split(whereSeparator: \.isWhitespace)
    // ["DEBIT", "03/05/2022", "Beanie", "Babies", "Are", "Back", "$57.33"]


    let individual = fragments[2...].dropLast().joined(separator: " ")

    // ... hard-coded access to rest of the fields ...

    transaction.split(omittingEmptySubsequences: false) { $0.isWhitespace }
    // ["DEBIT", "", "", "", "", "03/05/2022", "", "", "", "Beanie", "Babies", "Are", "Back", "", "", "", "$57.33"]

    print(fragments)


    print(individual)

    //    ["CREDIT", "", "", "", "03/02/2022", "", "", "", "Payroll", "from", "employer", "", "", "", "", "$200.23"]

//    let regex = try Regex("foo")
//
//    transaction.split()

//    let transaction = "DEBIT     03/05/2022    Beanie Babies Are Back    $57.33"

    let fieldSeparator = try! Regex(#"\s{2,}|\t"#)

    print(transaction.split(separator: fieldSeparator))//.joined(separator: "\t"))

    print("join")
    print(transaction.split(separator: fieldSeparator).joined(separator: "\t"))

    print("replacing")
    print(transaction.replacing(fieldSeparator, with: "\t"))

  }



  func testFooRuntime() throws {
    for line in statement.split(whereSeparator: { $0.isNewline }) {
      print(line)
    }

    let commandLineInput = "A"

    let fieldSeparator = try! Regex(#"\s{2,}|\t"#)

    let inputRegex = try! Regex(commandLineInput)
    let regex = Regex {
      Repeat(count: 2) {
        try! Regex(".*?")
        fieldSeparator
      }
      inputRegex
      try! Regex(".*")
    }

    print("-")
    for line in statement.split(whereSeparator: { $0.isNewline }) {
      if let m = try regex.wholeMatch(in: line) {
        print(m.0)
      }
    }

    print("--")

    for line in statement.split(whereSeparator: { $0.isNewline }) {
      if let m = Array(line.split(separator: fieldSeparator))[2].firstMatch(of: inputRegex) {
        print(line)
      }
      if let m = line.firstMatch(of: inputRegex) {
        print(line)
      }
    }


  }

  func testFooRuntime2() throws {
    let commandLineInput = "A"

    let inputRegex = try Regex(commandLineInput)
    // Regex<AnyRegexOutput>

    let specificRegex: Regex<(Substring, Substring)> = try Regex(commandLineInput)
  }

  func testFooUnicode() {

    let aZombieLoveStory = "🧟‍♀️💖🧠"

    let regex = try! Regex(#"""
      \y(?<base>.)(?:\N{ZERO WIDTH JOINER}(?<modifier>.).*?)?\y
      """#, as: (Substring, base: Substring, modifier: Substring?).self
    )//.matchingSemantics(.unicodeScalar)
    // Regex<(Substring, base: Substring, modifier: Substring?)>


    let regexMultiline = try! Regex(#"""
      (?x)
      \y (?<base> .) (?: \N{ZERO WIDTH JOINER} (?<modifier> .) .*?)? \y
      """#, as: (Substring, base: Substring, modifier: Substring?).self
    ).matchingSemantics(.unicodeScalar)
    // Regex<(Substring, base: Substring, modifier: Substring?)>

    for match in "🧟‍♀️💖🧠".matches(of: regex.matchingSemantics(.unicodeScalar)) {
      print("\(match.0) => \(match.base) | \(match.modifier ?? "<none>")")
    }

    let dotHeartdot = try! Regex(#".\N{SPARKLING HEART}."#)
    let anyCafe = try! Regex(#".*café"#).ignoresCase()

    switch ("🧟‍♀️💖🧠", "The Brain CafE\u{301}") {
    case (dotHeartdot, anyCafe):
      print("Oh no! 🧟‍♀️💖🧠, but 🧠💖☕️!")
    default:
      print("No conflicts found")
      fatalError()
    }

    switch "cafe\u{301}" {
    case try! Regex(#"...\p{Letter}"#):
      print("matched!")
    default:
      print("no match")
    }

  }

  func testHero() {
/*
    guard #available(macOS 12.0, *) else { return }

    Regex {
      let fieldSeparator = /\s{2,}|\t/
      Capture { /CREDIT|DEBIT/ }
      fieldSeparator

      Capture { Date.FormatStyle(date: .numeric).parseStrategy }
      fieldSeparator

      Capture {
        OneOrMore {
          Lookahead(negative: true) { fieldSeparator }
          CharacterClass.any
        }
      }
      fieldSeparator

      Capture { Decimal.FormatStyle.Currency(code: "USD") }
    }
    // Regex<(Substring, Substring, Date, Substring, Decimal)>

*/


    let regex = Regex {
      let fieldSeparator = try! Regex(#"\s{2,}|\t"#)
      Capture { try! Regex("CREDIT|DEBIT") }
      fieldSeparator

      Capture {
        try! Regex("[0-9/]")
      }
      fieldSeparator

      Capture {
        OneOrMore {
          Lookahead(negative: true) { "  " }
          CharacterClass.any
        }
      }
      fieldSeparator

      Capture { OneOrMore(CharacterClass.any) }
    }

    // FIXME: doesn't work!
    for match in statement.matches(of: regex) {
      print(match.0, match.1, match.2, match.3, match.4)
    }

  }

  func testRuntimeComponent() throws {
    let userString = #"CREDIT|DEBIT|.*"#
    let transferRegex = try Regex(userString)
    do {
      let regex = Regex {
        let fieldSeparator = try! Regex(#"\s{2,}|\t"#)
        Capture { transferRegex }
        fieldSeparator

        // ...
      }
      // let regex: Regex<(Substring, AnyRegexOutput)>

      print(try regex.wholeMatch(in: "CREDIT  ")!.1)


      print(try regex.wholeMatch(in: "CREDIT  ")!.0)
      print(try regex.wholeMatch(in: "DEBIT  ")!.0)
      print(try regex.wholeMatch(in: "DEBITasfd  ")!.0)
    }
    do {
      let regex = Regex {
        let fieldSeparator = try! Regex(#"\s{2,}|\t"#)
        Capture { Local { transferRegex } }
        fieldSeparator

        // ...
      }
      // let regex: Regex<(Substring, Substring)>

      print(try regex.wholeMatch(in: "CREDIT  ")!.1)

      // FIXME: Bug in local here, it seems to backtrack to .*

      print(try regex.wholeMatch(in: "CREDIT  ")!.0)
      print(try regex.wholeMatch(in: "DEBIT  ")!.0)
      print(try regex.wholeMatch(in: "DEBITasfd  ")!.0)
    }
  }

}

