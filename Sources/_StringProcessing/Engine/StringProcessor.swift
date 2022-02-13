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

// `preferNil` means return `nil` for an empty capture instead
// of "" or [].
private func _todo(
  _ node: CaptureStructure,
  _ list: CaptureList,
  _ curIdx: inout Int,
  fromOptional preferNil: Bool
) -> Capture? {

  if list.caps[curIdx].isEmpty {
    if preferNil {
      // TODO: Should we recurse down to make
      // `some(some(none))` or just return `none()`?
      return nil
    }
    switch node {
    case let .atom(name, type):
      // TODO: name
      _ = name

      

      // TODO: types?
      return .atom("")
    case .array(let a):
      print(a)

    case .optional(_):
      fatalError()
    case .tuple(_):
      fatalError()

    @unknown default:
      fatalError()

    }

  }


  fatalError()
}


internal func structuralize(
  _ caps: CaptureList,
  _ structure: CaptureStructure,
  _ input: String
) throws -> Capture {
  try structure.structuralize(caps, input)
}
