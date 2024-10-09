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

// MARK: Regex algorithms

@available(SwiftStdlib 5.7, *)
struct RegexMatchesCollection<Output> {
  let input: String
  let subjectBounds: Range<String.Index>
  let searchBounds: Range<String.Index>
  let regex: Regex<Output>
  let startIndex: Index
  
  init(
    input: String,
    subjectBounds: Range<String.Index>,
    searchBounds: Range<String.Index>,
    regex: Regex<Output>
  ) {
    self.input = input
    self.subjectBounds = subjectBounds
    self.searchBounds = searchBounds
    self.regex = regex
    self.startIndex = (try? regex._firstMatch(
      input,
      subjectBounds: subjectBounds,
      searchBounds: searchBounds)).map(Index.match) ?? .end
  }
}

@available(SwiftStdlib 5.7, *)
extension RegexMatchesCollection: Sequence {
  /// Returns the index to start searching for the next match after `match`.
  fileprivate func searchIndex(after match: Regex<Output>.Match) -> String.Index? {
    if !match.range.isEmpty {
      return match.range.upperBound
    }
    
    // If the last match was an empty match, advance by one position and
    // run again, unless at the end of `input`.
    if match.range.lowerBound == input.endIndex {
      return nil
    }
    
    switch regex.initialOptions.semanticLevel {
    case .graphemeCluster:
      return input.index(after: match.range.upperBound)
    case .unicodeScalar:
      return input.unicodeScalars.index(after: match.range.upperBound)
    }
  }

  struct Iterator: IteratorProtocol {
    let base: RegexMatchesCollection
    
    // Because `RegexMatchesCollection` eagerly computes the first match for
    // its `startIndex`, the iterator can use that match for its initial
    // iteration. For subsequent calls to `next()`, this value is `false`, and
    // `nextStart` is used to search for the next match.
    var initialIteration = true
    var nextStart: String.Index?
    
    init(_ matches: RegexMatchesCollection) {
      self.base = matches
      self.nextStart = base.startIndex.match.flatMap(base.searchIndex(after:))
    }
    
    mutating func next() -> Regex<Output>.Match? {
      // Initial case with pre-computed first match
      if initialIteration {
        initialIteration = false
        return base.startIndex.match
      }
      
      // `nextStart` is `nil` when iteration has completed
      guard let start = nextStart, start <= base.searchBounds.upperBound else {
        return nil
      }
      
      // Otherwise, find the next match (if any) and compute `nextStart`
      let match = try? base.regex._firstMatch(
        base.input,
        subjectBounds: base.subjectBounds,
        searchBounds: start..<base.searchBounds.upperBound)
      nextStart = match.flatMap(base.searchIndex(after:))
      return match
    }
  }
  
  func makeIterator() -> Iterator {
    Iterator(self)
  }
}

@available(SwiftStdlib 5.7, *)
extension RegexMatchesCollection: Collection {
  enum Index: Comparable {
    case match(Regex<Output>.Match)
    case end
    
    var match: Regex<Output>.Match? {
      switch self {
      case .match(let match): return match
      case .end: return nil
      }
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
      switch (lhs, rhs) {
      case (.match(let lhs), .match(let rhs)):
        return lhs.range == rhs.range
      case (.end, .end):
        return true
      case (.end, .match), (.match, .end):
        return false
      }
    }
    
    static func < (lhs: Self, rhs: Self) -> Bool {
      switch (lhs, rhs) {
      case (.match(let lhs), .match(let rhs)):
        // This implementation uses a tuple comparison so that an empty
        // range `i..<i` will be ordered before a non-empty range at that
        // same starting point `i..<j`. As of 2022-05-30, `Regex` does not
        // return matches of this kind, but that is one behavior under
        // discussion for regexes like /a*|b/ when matched against "b".
        return (lhs.range.lowerBound, lhs.range.upperBound)
          < (rhs.range.lowerBound, rhs.range.upperBound)
      case (.match, .end):
        return true
      case (.end, .match), (.end, .end):
        return false
      }
    }
  }
  
  var endIndex: Index {
    Index.end
  }
  
  func index(after i: Index) -> Index {
    guard let currentMatch = i.match else {
      fatalError("Can't advance past the 'endIndex' of a match collection.")
    }
    
    guard
      let start = searchIndex(after: currentMatch),
      start <= searchBounds.upperBound,
      let nextMatch = try? regex._firstMatch(
        input,
        subjectBounds: subjectBounds,
        searchBounds: start..<searchBounds.upperBound)
    else {
      return .end
    }
    return Index.match(nextMatch)
  }
  
  subscript(position: Index) -> Regex<Output>.Match {
    guard let match = position.match else {
      fatalError("Can't subscript the 'endIndex' of a match collection.")
    }
    return match
  }
}

extension BidirectionalCollection where SubSequence == Substring {
  @available(SwiftStdlib 5.7, *)
  @_disfavoredOverload
  func _matches<R: RegexComponent>(
    of regex: R
  ) -> RegexMatchesCollection<R.RegexOutput> {
    RegexMatchesCollection(
      input: self[...].base,
      subjectBounds: startIndex..<endIndex,
      searchBounds: startIndex..<endIndex,
      regex: regex.regex)
  }

  // FIXME: Return `some Collection<Regex<R.Output>.Match> for SE-0346
  /// Returns a collection containing all matches of the specified regex.
  /// - Parameter regex: The regex to search for.
  /// - Returns: A collection of matches of `regex`.
  @available(SwiftStdlib 5.7, *)
  public func matches<Output>(
    of r: some RegexComponent<Output>
  ) -> [Regex<Output>.Match] {
    // FIXME: Array init calls count, which double-executes the regex :-(
    // FIXME: just return some Collection<Regex<Output>.Match>
    var result = Array<Regex<Output>.Match>()
    for match in _matches(of: r) {
      result.append(match)
    }
    return result
  }
}
