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

import _MatchingEngine
typealias Program = MEProgram<String>

public struct MatchResult {
  public var range: Range<String.Index>
  var captures: Capture

  var destructure: (
    matched: Range<String.Index>, captures: Capture
  ) {
    (range, captures)
  }

  init(
    _ matched: Range<String.Index>, _ captures: Capture
  ) {
    self.range = matched
    self.captures = captures
  }
}

// TODO: Where does this go?

internal func structuralize(
  _ caps: CaptureList,
  _ structure: CaptureStructure,
  _ input: String
) throws -> Capture {
  let caps = caps.caps

//  print(structure)
//  print(caps)

  // Captures are flat in depth-first pre-order
  var curIdx = caps.startIndex
  func rec(_ node: CaptureStructure) throws -> Capture {
    switch node {
    case let .atom(name, type):
      _ = name // TODO: What to do with names?
      _ = type // TODO: What to do with type?

      let capture = caps[curIdx]
      defer { caps.formIndex(after: &curIdx) }

      // TODO: Is here where we should detect optionality?
      // Or should that be passed down to us?

      guard !capture.isEmpty else {
        // FIXME: Atom-of-optional, or should we have a
        // different tree structure?
        guard let t = type else {
//          print(capture)
//          print(node)
          fatalError("What goes here?")
        }
        return .none(childType: t)
      }

      assert(
        capture.history.count == 1,
        "Err, what should we do?")

      if let t = type {
        guard let value = capture.latestValue else {
          throw Unreachable(
            "Mismatch between structure and captrues")
        }
        // FIXME: How do I assert the `Any` is of type `t`?
        _ = t

        return .atom(value)
      }

      return .atom(input[capture.latest!])

    case let .array(a):
      let capture = caps[curIdx]

      // TODO: Need to refactor to support nesting...
      guard case let .atom(name, type) = a else {
        print(capture)
        print(node)
        throw Unsupported("FIXME: nesting")
      }
      _ = name

      defer { caps.formIndex(after: &curIdx) }

      if let t = type {
        let values = capture.valueHistory.map {
          Capture.atom($0)
        }
        return .array(values, childType: t)
      }

      let capStrs = capture.history.map {
        Capture.atom(input[$0])
      }
      return .array(capStrs, childType: a.type)

    case let .optional(o):
      // FIXME: How does nesting work? Would this consume a
      // capture or not?
      let capHistory = caps[curIdx]
      if capHistory.isEmpty {
        caps.formIndex(after: &curIdx)
        return .none(childType: o.type)
      }
//      print("optional: \(capHistory)")
      let child = try rec(o)

      return .some(child)

    case let .tuple(ts):
//      print("tuple:\n\(ts)")
      let elements = try ts.map { t -> Capture in
//        print("inside map: \(t)")
        return try rec(t)
      }
      return .tuple(elements)

    @unknown default:
      throw Unreachable("Version mismatch with regex parser")
    }
  }

  let res = try rec(structure)
  return res
}
