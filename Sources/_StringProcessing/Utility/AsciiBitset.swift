/// A simple 128-bit vector representing a set of 7-bit ASCII values.
///
/// TODO(perf): Look into SIMD alternative and faster queries
internal struct _AsciiBitset {
  var a: UInt64 = 0
  var b: UInt64 = 0

  private mutating func setBit(_ val: UInt8) {
    assert(val._isASCII)
    if val < 64 {
      a = a | 1 << val
    } else {
      b = b | 1 << (val - 64)
    }
  }

  internal mutating func insert(_ val: UInt8, _ isCaseInsensitive: Bool) {
    assert(val._isASCII)
    setBit(val)
    if isCaseInsensitive, let v = val._asciiCaseSwapped {
      setBit(v)
    }
  }

  internal mutating func union(_ other: AsciiBitset) {
    a |= other.a
    b |= other.b
  }

  internal func isSet(_ val: UInt8) -> Bool {
    assert(val._isASCII)
    if val < 64 {
      return (a >> val) & 1 == 1
    } else {
      return (b >> (val - 64)) & 1 == 1
    }
  }
}



  // TODO: refactor below...
  internal func matches(_ char: Character) -> Bool {
    let matched: Bool
    if let val = char._singleScalarAsciiValue {
      matched = _matchesWithoutInversion(val)
    } else {
      matched = false
    }

    if isInverted {
      return !matched
    }
    return matched
  }

  internal func matches(_ scalar: Unicode.Scalar) -> Bool {
    let matched: Bool
    if scalar.isASCII {
      let val = UInt8(ascii: scalar)
      matched = _matchesWithoutInversion(val)
    } else {
      matched = false
    }

    if isInverted {
      return !matched
    }
    return matched
  }

  /// Joins another bitset from a Member of the same CustomCharacterClass
  internal func union(_ other: AsciiBitset) -> AsciiBitset {
    precondition(self.isInverted == other.isInverted)
    return AsciiBitset(
      a: self.a | other.a,
      b: self.b | other.b,
      isInverted: self.isInverted
    )
  }
}

extension DSLTree.CustomCharacterClass {
  func asAsciiBitset(_ opts: MatchingOptions) -> AsciiBitset? {
    return members.reduce(
      .init(isInverted: isInverted),
      {result, member in
        if let next = member.asAsciiBitset(opts, isInverted) {
          return result?.union(next)
        } else {
          return nil
        }
      }
    )
  }
}

extension DSLTree.CustomCharacterClass.Member {
  func asAsciiBitset(
    _ opts: MatchingOptions,
    _ isInverted: Bool
  ) -> DSLTree.CustomCharacterClass.AsciiBitset? {
    typealias Bitset = DSLTree.CustomCharacterClass.AsciiBitset
    switch self {
    case let .atom(a):
      if let val = a.singleScalarASCIIValue {
        return Bitset(val, isInverted, opts.isCaseInsensitive)
      }
    case let .range(low, high):
      if let lowVal = low.singleScalarASCIIValue,
         let highVal = high.singleScalarASCIIValue {
        return Bitset(low: lowVal, high: highVal, isInverted: isInverted,
                      isCaseInsensitive: opts.isCaseInsensitive)
      }
    case .quotedLiteral(let str):
      var bitset = Bitset(isInverted: isInverted)
      for c in str {
        guard let ascii = c._singleScalarAsciiValue else { return nil }
        bitset = bitset.union(Bitset(ascii, isInverted, opts.isCaseInsensitive))
      }
      return bitset
    default:
      return nil
    }
    return nil
  }
}

