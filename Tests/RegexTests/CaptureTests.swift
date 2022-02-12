
import XCTest
@testable import _StringProcessing
import _MatchingEngine

extension Capture: ExpressibleByStringLiteral {
  fileprivate init(_ s: String) {
    self = .atom(s[...])
  }
  public init(stringLiteral: String) {
    self.init(stringLiteral)
  }
}

// TODO: Move `flatCaptureTest`s over here too...

private func isEqual(_ lhs: Capture, _ rhs: Capture) -> Bool {
  switch (lhs, rhs) {
  case let (.atom(a), .atom(b)):
    // FIXME: Needed because "a" != "a"[...] existentially
    let lhsStr = String(describing: a)
    let rhsStr = String(describing: b)

    // :-(
    return lhsStr == rhsStr

  case let (.tuple(a), .tuple(b)):
    return zip(a, b).map(isEqual).all({$0})
  case let (.some(a), .some(b)):
    return isEqual(a, b)
  case let (.none(a), .none(b)):
    return a == b
  case let (.array(a, tA), .array(b, tB)):
    let contentsCompare = zip(a, b).map(isEqual).all({$0})
    return contentsCompare && tA == tB

  default: return false
  }
}

func compileBoth(_ ast: AST) -> (Executor, HareVM) {
  let tree = ast.dslTree
  let prog = try! Compiler(tree: tree).emit()
  let executor = Executor(program: prog)

  let code = try! compile(ast)
  let vm = HareVM(program: code)

  return (executor, vm)
}

func captureTest(
  _ regex: String,
  _ expected: CaptureStructure,
  _ tests: (input: String, output: Capture)...,
  skipLegacy: Bool = false
) {

  let ast = try! parse(regex, .traditional)
  let capStructure = ast.captureStructure
  guard capStructure == expected else {
    XCTFail("""
        Expected:
        \(expected)
        Actual:
        \(capStructure)
        """)
    return
  }

  // Ensure DSLTree preserves literal captures
  let dslCapStructure = ast.dslTree.captureStructure
  guard dslCapStructure == capStructure else {
    XCTFail("""
      DSLTree did not preserve structure:
      AST:
      \(capStructure)
      DSLTree:
      \(dslCapStructure)
      """)
    return
  }

  let (executor, vm) = compileBoth(ast)

  for (input, output) in tests {
    let inputRange = input.startIndex..<input.endIndex
    let (_, capFlat) = executor.executeFlat(
      input: input, in: inputRange, mode: .wholeString
    )!

    let cap = try! structuralize(
      capFlat, capStructure, input)

    guard isEqual(cap, output) else {
      XCTFail("""
      regex: \(regex), input: "\(input)"
      Structure:
      \(capStructure)
      Capture list:
      \(capFlat.latestUntyped(from: input))
      Expected:
      \(output)
      Actual:
      \(cap)
      """)
      continue
    }

    guard !skipLegacy else { continue }

    let (_, vmCap) = vm.execute(
      input: input, mode: .wholeString
    )!.destructure

    guard isEqual(vmCap, output) else {
      XCTFail("""
      regex: \(regex), input: "\(input)"
      Capture Structure:
      \(capStructure)
      Legacy VM Capture:
      \(vmCap)
      """)
      continue
    }
  }
}

extension RegexTests {

  func testLiteralStructuredCaptures() throws {
    func some(_ c: Capture) -> Capture {
      .some(c)
    }

    func array(_ cs: Capture...) -> Capture {
      .array(cs, childType: Substring.self)
    }
    func someArray(_ cs: Capture...) -> Capture {
      .some(.array(cs, childType: Substring.self))
    }

    func tuple(_ ss: Capture...) -> Capture {
      .tuple(ss)
    }

    var none: Capture {
      .none(childType: Substring.self)
    }
    var noArray: Capture {
      .none(childType: [Substring].self)
    }
    var noOpt: Capture {
      .none(childType: Substring?.self)
    }

    captureTest(
      "abc",
      .empty,
      ("abc", .void))

    captureTest(
      "a(b)c",
      .atom(),
      ("abc", "b"))

    captureTest(
      "a(b*)c",
      .atom(),
      ("abc", "b"),
      ("ac", ""),
      ("abbc", "bb"))

    captureTest(
      "a(b)*c",
      .array(.atom()),
      ("abc", array("b")),
      ("ac", array("")),
      ("abbc", array("b", "b")))

    captureTest(
      "a(b)+c",
      .array(.atom()),
      ("abc", array("b")),
      ("abbc", array("b", "b")))

    captureTest(
      "a(b)?c",
      .optional(.atom()),
      ("ac", none),
      ("abc", some("b")))

    captureTest(
      "(a)(b)(c)",
      .tuple([.atom(),.atom(),.atom()]),
      ("abc", tuple("a", "b", "c")))

    captureTest(
      "a|(b)",
      .optional(.atom()),
      ("a", none),
      ("b", some("b")),
      skipLegacy: true)

    captureTest(
      "(a)|(b)",
      .tuple(.optional(.atom()), .optional(.atom())),
      ("a", tuple(some("a"), none)),
      ("b", tuple(none, some("b"))),
      skipLegacy: true)

    captureTest(
      "((a)|(b))",
      .tuple(.atom(), .optional(.atom()), .optional(.atom())),
      ("a", tuple("a", some("a"), none)),
      ("b", tuple("b", none, some("b"))),
      skipLegacy: true)

    captureTest(
      "((a)|(b))?",
      .tuple(
        .optional(.atom()),
        .optional(.optional(.atom())),
        .optional(.optional(.atom()))),
      ("a", tuple(some("a"), .some(some("a")), noOpt)),
      ("b", tuple(some("b"), noOpt, .some(some("b")))),
      skipLegacy: true)

//    captureTest(
//      "((a)|(b))*",
//      .tuple(
//        .array(.atom()),
//        .array(.optional(.atom())),
//        .array(.optional(.atom()))),
//      ("a", .tuple([yes("a"), .some(yes("a")), noOpt])),
//      ("b", .tuple([yes("b"), noOpt, .some(yes("b"))])),
//      skipLegacy: true)
//
//    captureTest(
//      "((a)|(b))+",
//      .optional(.atom()),
//      ("a", no()),
//      ("b", yes("b")),
//      skipLegacy: true)
//
//    captureTest(
//      "(((a)|(b))*)",
//      .tuple(
//        .atom(),
//        .array(.atom()),
//        .array(.optional(.atom())),
//        .array(.optional(.atom()))),
//      ("a", tuple("a", array("a"), array(some("a")), noOpt)),
//      ("b", tuple("b", array("b"), noOpt, array(some("b")))),
//      // FIXME: Should above `noneOpt`s be `some(none)`s?
//      skipLegacy: true)

    captureTest(
      "(((a)|(b))?)",
      .tuple(
        .atom(),
        .optional(.atom()),
        .optional(.optional(.atom())),
        .optional(.optional(.atom()))),
      ("a", tuple("a", some("a"), some(some("a")), noOpt)),
      ("b", tuple("b", some("b"), noOpt, some(some("b")))),
      // FIXME: Should above `noneOpt`s be `some(none)`s?
      skipLegacy: true)

    captureTest(
      "(a)",
      .atom(),
      ("a", "a"))

    captureTest(
      "((a))",
      .tuple([.atom(), .atom()]),
      ("a", tuple("a", "a")),
      skipLegacy: true)

    captureTest(
      "(((a)))",
      .tuple([.atom(), .atom(), .atom()]),
      ("a", tuple("a", "a", "a")),
      skipLegacy: true)

    captureTest(
      "a|(b*)",
      .optional(.atom()),
      ("a", none),
      ("", some("")),
      ("b", some("b")),
      ("bbb", some("bbb")),
      skipLegacy: true)

    captureTest(
      "a|(b)*",
      .optional(.array(.atom())),
      ("a", noArray),
      ("", noArray),
      ("b", someArray("b")),
      ("bbb", someArray("b", "b", "b")),
      skipLegacy: true)

    captureTest(
      "a|(b)+",
      .optional(.array(.atom())),
      ("a", noArray),
      ("b", someArray("b")),
      ("bbb", someArray("b", "b", "b")),
      skipLegacy: true)

    captureTest(
      "a|(b)?",
      .optional(.optional(.atom())),
      ("a", noOpt),
      ("", noOpt),
      ("b", .some(some("b"))),
      skipLegacy: true)

    captureTest(
      "a|(b|c)",
      .optional(.atom()),
      ("a", none),
      ("b", some("b")),
      ("c", some("c")),
      skipLegacy: true)

    captureTest(
      "a|(b*|c)",
      .optional(.atom()),
      ("a", none),
      ("b", some("b")),
      ("c", some("c")),
      skipLegacy: true)

    captureTest(
      "a|(b|c)*",
      .optional(.array(.atom())),
      ("a", noArray),
      ("", noArray),
      ("b", someArray("b")),
      ("bbb", someArray("b", "b", "b")),
      skipLegacy: true)

    captureTest(
      "a|(b|c)?",
      .optional(.optional(.atom())),
      ("a", noOpt),
      ("", noOpt),
      ("b", .some(some("b"))),
      ("c", .some(some("c"))),
      skipLegacy: true)


    captureTest(
      "a(b(c))",
      .tuple(.atom(), .atom()),
      ("abc", tuple("bc", "c")),
      skipLegacy: true)

    captureTest(
      "a(b(c*))",
      .tuple(.atom(), .atom()),
      ("ab", tuple("b", "")),
      ("abc", tuple("bc", "c")),
      ("abcc", tuple("bcc", "cc")),
      skipLegacy: true)

    captureTest(
      "a(b(c)*)",
      .tuple(.atom(), .array(.atom())),
      ("ab", tuple("b", array(""))),
      ("abc", tuple("bc", array("c"))),
      ("abcc", tuple("bcc", array("c", "c"))),
      skipLegacy: true)

    captureTest(
      "a(b(c)?)",
      .tuple(.atom(), .optional(.atom())),
      ("ab", tuple("b", none)),
      ("abc", tuple("bc", some("c"))),
      skipLegacy: true)


    captureTest(
      "a(b(c))*",
      .tuple(.array(.atom()), .array(.atom())),
      ("a", tuple(array(""), array(""))),
      ("abc", tuple(array("bc"), array("c"))),
      ("abcbc", tuple(array("bc", "bc"), array("c", "c"))),
      skipLegacy: true)

    captureTest(
      "a(b(c))?",
      .tuple(.optional(.atom()), .optional(.atom())),
      ("a", tuple(none, none)),
      ("abc", tuple(some("bc"), some("c"))),
      skipLegacy: true)

  }

}

