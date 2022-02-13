import _MatchingEngine

private enum StructureKind {
  case optional
  case history
  case latest
}
extension StructureKind: CustomStringConvertible {
  var description: String {
    switch self {
    case .optional: return "optional"
    case .history: return "history"
    case .latest: return "latest"
    }
  }
}

/*

2 functions

- one is top-level which extracts a capture
  - array will get a _storedcapture and map over it
  - optional will check history
  - atom will pass down latest
  - tuple will be self-recursion point? for each

- second takes a stored capture and recurses until atom
  - array will 



- optional(atom) is weird case
  - optional(n) is .some(rec(n))
- array(atom) means use history
  - array(n), without nested tuples, means extract and pass
  - array(....tuple(...)), 


- array calls `f` to get array of captures
  - or array asks how many covered captures to extract
  - 


- We record stack on way down  
- atom will chew on the stack up until a tuple point
  - `extract` point or whatever
- tuple will run each child with a fresh stack
- assert for now no nested tuples
  - array(tuple(atom, atom)) -> [(firstA, firstB), (...)]
    - i.e. it's a zip...
  - array(optional(...)) -> [some, some, none, some]
    - would it be if range is empty?

- tuple comes down and says zip, if there's an array above it
  - for now we assert/fail if visit stack is non-empty


- intermediary tree?
  -   

*/

// TODO: How stateful is this, really?
// TODO: Should we build up a result more mutably?
private struct Fabricator {
  var list: CaptureList
  let input: String

  var curIdx = 0
  var structStack: Array<StructureKind> = []

  mutating func next(
  ) throws -> Processor<String>._StoredCapture {
    guard curIdx < list.caps.endIndex else {
      // TODO: Is `throws` a bit much here?
      // Maybe just precondition or hard trap
      throw Unreachable("Capture count mismatch")
    }
    defer { list.caps.formIndex(after: &curIdx) }
    return list.caps[curIdx]
  }

  var currentIsEmpty: Bool {
    guard curIdx < list.caps.endIndex else {
      fatalError("Capture count mismatch")
    }

    return list.caps[curIdx].isEmpty
  }

  mutating func formValue(
    _ t: AnyType
  ) throws -> Capture {
    let cap = try next()

    switch structStack.last {
    case nil, .latest:
      guard let v = cap.latestValue else {
        // TODO: Should we actually be tracking whether there
        // were any optionals along the way, or just the latest
        // kind?
        throw Unreachable("No actual capture recorded")
      }
      guard type(of: v) == t.base else {
        throw Unreachable("Type mismatch")
      }
      return .atom(v)

    case .history:
      let hist = try cap.valueHistory.map { v -> Capture in
        guard type(of: v) == t.base else {
          throw Unreachable("Type mismatch")
        }
        return .atom(v)
      }
      return .array(hist, childType: t)

    case .optional:
      if cap.valueHistory.isEmpty {
        return .none(childType: t)
      }
      guard let v = cap.latestValue else {
        // TODO: Should we actually be tracking whether there
        // were any optionals along the way, or just the latest
        // kind?
        throw Unreachable("No actual capture recorded")
      }
      guard type(of: v) == t.base else {
        throw Unreachable("Type mismatch")
      }
      return .some(.atom(v))
    }
  }

  mutating func formSlice(
  ) throws -> Capture {
    //print(self)
//    print(self.structStack)
    let cap = try next()

    switch structStack.last {
    case nil, .latest:
      guard let r = cap.latest else {
        // TODO: Should we actually be tracking whether there
        // were any optionals along the way, or just the latest
        // kind?
        throw Unreachable("No actual capture recorded")
      }
      return .atom(input[r])

    case .history:
      let hist = cap.history.map { r -> Capture in
        return .atom(input[r])
      }
      return .array(hist, childType: Substring.self)

    case .optional:
      guard let r = cap.history.last else {
        return .none(childType: Substring.self)
      }
      return .some(.atom(input[r]))
    }
  }
}

extension CaptureStructure {
  func structuralize(
    _ list: CaptureList,
    _ input: String
  ) throws -> Capture {
    var fab = Fabricator(list: list, input: input)
    return try _structuralize(&fab)
  }

  private func _structuralize(
    _ fab: inout Fabricator
  ) throws -> Capture {
    switch self {
    case let .atom(name, type):
      // TODO: names
      guard name == nil else {
        throw Unsupported("names...")
      }

      if let t = type {
        return try fab.formValue(t)
      }
      return try fab.formSlice()

    case let .array(a):
      fab.structStack.append(.history)
      defer { fab.structStack.removeLast() }
      return try a._structuralize(&fab)

    case let .optional(o):
      // NOTE: This has the effect of flattening nested
      // optionals. Not sure what we actually want here.
      //
      // Also, this will not add optional to nested types,
      // again not sure what we want...
      fab.structStack.append(.optional)
      defer { fab.structStack.removeLast() }
      return try o._structuralize(&fab)

    case let .tuple(t):
      let members = try t.map { try $0._structuralize(&fab) }
      return .tuple(members)

    @unknown default:
      throw Unreachable("Version mismatch with parser")
    }
  }
}
