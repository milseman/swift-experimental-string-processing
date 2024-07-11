//import Future


/*

 Demonstration of using UTF8Span's API to construct views

 */

extension UTF8Span {
  // TODO: remove
  public typealias Index = Int



//  public typealias CodeUnits = Span<UInt8>
//
//  @inlinable @inline(__always)
//  public var codeUnits: CodeUnits {
//    .init(
//      unsafeStart: unsafeBaseAddress,
//      byteCount: count,
//      owner: self)
//  }
  typealias UTF8View = Self
  var utf8: Self { self }

  @frozen
  public struct UnicodeScalarView: ~Escapable {
    @inline(__always)
    public let span: UTF8Span

    @inlinable @inline(__always)
    public init(_ span: UTF8Span) {
      self.span = span
    }
  }

  @inlinable @inline(__always)
  public var unicodeScalars: UnicodeScalarView {
    _read { yield .init(self) }
  }

  @frozen
  public struct CharacterView: ~Escapable {
    @inline(__always)
    public let span: UTF8Span

    @inlinable @inline(__always)
    public init(_ span: UTF8Span) {
      self.span = span
    }
  }

  @inlinable @inline(__always)
  public var characters: CharacterView {
    _read { yield .init(self) }
  }

  @frozen
  public struct UTF16View: ~Escapable {
    @inline(__always)
    public let span: UTF8Span

    @inlinable @inline(__always)
    public init(_ span: UTF8Span) {
      self.span = span
    }
  }

  @inlinable @inline(__always)
  public var utf16: UTF16View {
    _read { yield .init(self) }
  }

}


extension UTF8Span.UnicodeScalarView {
  // NOTE: I decided not to store the length, or the scalar value itself.
  // Storing the length wouldn't speed up subscript that much and would
  // require that index(after:) load the subsequent byte. We'll still have a
  // custom iterator. I decided not to store the scalar value as that would
  // slow down index-only operations
  //
  // NOTE: `indices` returns `Range<Index>` which means that `indices.contains
  // (i)` will return true for `i >= indices.lowerBounds && i <=
  // indices.upperBound`, whether aligned or not
  //
  // TODO: Should it be RawSpan.Index, so that we can do allocation checking?
  //
  // Note: Wrapper struct, but with public access, so that it's not used
  // across views accidentally
//  @frozen
//  public struct Index: Comparable, Hashable {
//    public var position: Int
//
//    // TODO: Do we want the public init to take the span so we can
//    // precondition that it's aligned?
//    @inlinable @inline(__always)
//    public init(_ position: Int) {
//      self.position = position
//    }
//
//    @inlinable @inline(__always)
//    public static func < (
//      lhs: UTF8Span.UnicodeScalarView.Index,
//      rhs: UTF8Span.UnicodeScalarView.Index
//    ) -> Bool {
//      lhs.position < rhs.position
//    }
//  }
  public typealias Index = Int

  public typealias Element = Unicode.Scalar

  @frozen
  public struct Iterator: ~Escapable {
    public typealias Element = Unicode.Scalar

    @inline(__always)
    public let span: UTF8Span

    @inline(__always)
    public var position: Int

    @inlinable @inline(__always)
    init(_ span: UTF8Span) {
      self.span = span
      self.position = 0
    }

    @inlinable
    public mutating func next() -> Unicode.Scalar? {
      guard position < span.count else {
        return nil
      }
      let (res, pos) = span.decodeNextScalar(
        uncheckedAssumingAligned: position)
      position = pos
      return res
    }
  }

  @inlinable @inline(__always)
  public borrowing func makeIterator() -> Iterator {
    .init(span)
  }

  @inlinable @inline(__always)
  public var startIndex: Index { .init(0) }

  @inlinable @inline(__always)
  public var endIndex: Index { .init(span.count) }

//  @inlinable @inline(__always)
//  public var count: Int { fatalError() }

//  @inlinable @inline(__always)
//  public var isEmpty: Bool { startIndex == endIndex }

//  @inlinable @inline(__always)
//  public var indices: Range<Index> {
//    startIndex..<endIndex
//  }

  @inlinable
  public func index(after i: Index) -> Index {
    .init(span.nextScalarStart(i))
  }

  @inlinable
  func formIndex(after i: inout Index) {
    i = index(after: i)
  }

  @inlinable
  public func index(before i: Index) -> Index {
    .init(span.previousScalarStart(uncheckedAssumingAligned: i))
  }

  @inlinable
  public subscript(_ i: Index) -> Element {
    borrowing _read {
      yield span.decodeNextScalar(i).0
    }
  }

#if false
  @inlinable
  public subscript(unchecked position: Index) -> Element {
    borrowing _read {
      fatalError()
    }
  }

  @inlinable
  public subscript(bounds: Range<Index>) -> Self {
    get {
      fatalError()
    }
  }

  @inlinable
  public subscript(unchecked bounds: Range<Index>) -> Self {
    borrowing get {
      fatalError()
    }
  }

  @_alwaysEmitIntoClient
  public subscript(bounds: some RangeExpression<Index>) -> Self {
    borrowing get {
      fatalError()
    }
  }

  @_alwaysEmitIntoClient
  public subscript(unchecked bounds: some RangeExpression<Index>) -> Self {
    borrowing get {
      fatalError()
    }
  }

  @_alwaysEmitIntoClient
  public subscript(x: UnboundedRange) -> Self {
    borrowing get {
      fatalError()
    }
  }

  @inlinable
  public func elementsEqual(_ other: Self) -> Bool {

  }

  // NOTE: No Collection overload, since it's the same code as
  // the sequence one.

  @inlinable
  public func elementsEqual(_ other: some Sequence<Element>) -> Bool {
    var iter = self.makeIterator()
    for elt in other {
      guard elt == iter.next() else { return false }
    }
    return iter.next() == nil
  }
#endif


}

extension UTF8Span.CharacterView {
  // NOTE: I decided not to store the length, so that
  // index after doesn't need to measure the next grapheme cluster.
  // We define a custom iterator to make iteration faster.
  //
  // Because the next-after-next grapheme cluster may be arbitrarily large, I
  // think it's better not to measure it pre-emptively as part of index
  // (after:). Instead we'll do exactly the operation the programmer asked
  // for.
  //
  // Note: Wrapper struct, but with public access, so that
  // it's not used across views accidentally
//  @frozen
//  public struct Index: Comparable, Hashable {
//    public var position: Int
//
//    @inlinable @inline(__always)
//    public init(_ position: Int) {
//      self.position = position
//    }
//
//    @inlinable @inline(__always)
//    public static func < (
//      lhs: UTF8Span.CharacterView.Index,
//      rhs: UTF8Span.CharacterView.Index
//    ) -> Bool {
//      lhs.position < rhs.position
//    }
//  }
  public typealias Index = Int

  public typealias Element = Character

  @frozen
  public struct Iterator: ~Escapable {
    public typealias Element = Character

    @inline(__always)
    public let span: UTF8Span

    @inline(__always)
    public var position: Int

    @inlinable @inline(__always)
    init(_ span: UTF8Span) {
      self.span = span
      self.position = 0
    }

    @inlinable
    public mutating func next() -> Character? {
      guard position < span.count else {
        return nil
      }
      let (res, pos) = span.decodeNextCharacter(
        uncheckedAssumingAligned: position)
      position = pos
      return res
    }
  }

  @inlinable @inline(__always)
  public borrowing func makeIterator() -> Iterator {
    .init(span)
  }

  @inlinable @inline(__always)
  public var startIndex: Index { .init(0) }

  @inlinable @inline(__always)
  public var endIndex: Index { .init(span.count) }

  @inlinable @inline(__always)
  public func formIndex(after i: inout Index) {
    i = index(after: i)
  }

  @inlinable
  public func index(after i: Index) -> Index {
    .init(span.nextCharacterStart(i))
  }

  @inlinable
  public func index(before i: Index) -> Index {
    .init(span.previousCharacterStart(i))
  }

  @inlinable
  public subscript(_ i: Index) -> Element {
    borrowing _read {
      yield span.decodeNextCharacter(i).0
    }
  }

  var isEmpty: Bool {
    startIndex == endIndex
  }

  var first: Character? {
    if isEmpty { return nil }
    return self[startIndex]
  }
}

extension UTF8Span {
  public func isOnGraphemeClusterBoundary(_ i: Index) -> Bool {
    isCharacterAligned(i)
  }

  @inlinable
  public subscript(bounds: some RangeExpression<Index>) -> Self {
    borrowing _read {
      yield self.extracting(bounds)
    }
  }


  /// Index after in either grapheme or scalar view
  func index(after idx: Index, isScalarSemantics: Bool) -> Index {
    if isScalarSemantics {
      return unicodeScalars.index(after: idx)
    } else {
      return characters.index(after: idx)
    }
  }
//
//  var first: Character? {
//    if isEmpty { return nil }
//    return decodeNextCharacter(0).0
//  }
//
//  var endIndex: Index {
//    count
//  }
//

  // TODO: cleaner to make a proper UTF8View...
  @inlinable
  func formIndex(after i: inout Index) {
    i += 1
  }
  @inlinable
  func index(after i: Index) -> Index {
    i+1
  }
  @inlinable
  func index(before i: Index) -> Index {
    i-1
  }


}

