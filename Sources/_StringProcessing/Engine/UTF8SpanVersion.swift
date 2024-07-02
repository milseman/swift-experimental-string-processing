
// MARK: - MEQuantify

internal typealias ASCIIBitset = DSLTree.CustomCharacterClass.AsciiBitset
extension UTF8Span {
  /// Run the quant loop, using the supplied matching closure
  ///
  /// NOTE: inline-always to help elimiate the closure overhead,
  /// simplify some of the looping structure, etc.
  @inline(__always)
  internal func _runQuantLoop(
    at currentPosition: Index,
    limitedBy end: Index,
    minMatches: UInt64,
    maxMatches: UInt64,
    produceSavePointRange: Bool,
    isScalarSemantics: Bool,
    _ doMatch: (
     _ currentPosition: Index, _ limitedBy: Index, _ isScalarSemantics: Bool
    ) -> Index?
  ) -> (next: Index, savePointRange: Range<Index>?)? {
    var currentPosition = currentPosition

    // The range of backtracking positions to try. For zero-or-more, starts
    // before any match happens. Always ends before the final match, since
    // the final match is what is tried without backtracking. An empty range
    // is valid and means a single backtracking position at rangeStart.
    var rangeStart = currentPosition
    var rangeEnd = currentPosition

    var numMatches = 0

    while numMatches < maxMatches {
      guard let next = doMatch(
        currentPosition, end, isScalarSemantics
      ) else {
        break
      }
      numMatches &+= 1
      if numMatches == minMatches {
        // For this loop iteration, rangeEnd will actually trail rangeStart by
        // a single match position. Next iteration, they will be equal
        // (empty range denoting a single backtracking point). Note that we
        // only ever return a range if we have exceeded `minMatches`; if we
        // exactly match `minMatches` there is no backtracking positions to
        // remember.
        rangeStart = next
      }
      rangeEnd = currentPosition
      currentPosition = next
      assert(currentPosition > rangeEnd)
    }

    guard numMatches >= minMatches else {
      return nil
    }

    guard produceSavePointRange && numMatches > minMatches else {
      // No backtracking positions to try
      return (currentPosition, nil)
    }
    assert(rangeStart <= rangeEnd)

    // NOTE: We can't assert that rangeEnd trails currentPosition by exactly
    // one position, because newline-sequence in scalar semantic mode still
    // matches two scalars

    return (
      currentPosition,
      Range(uncheckedBounds: (lower: rangeStart, upper: rangeEnd))
    )
  }

  // NOTE: [Zero|One]OrMore overloads are to specialize the inlined run loop,
  // which has a perf impact. At the time of writing this, 10% for
  // zero-or-more and 5% for one-or-more improvement, which could very well
  // be much higher if/when the inner match functions are made faster.

  internal func matchZeroOrMoreASCIIBitset(
    _ asciiBitset: ASCIIBitset,
    at currentPosition: Index,
    limitedBy end: Index,
    produceSavePointRange: Bool,
    isScalarSemantics: Bool
  ) -> (next: Index, savePointRange: Range<Index>?)? {
    _runQuantLoop(
      at: currentPosition,
      limitedBy: end,
      minMatches: 0,
      maxMatches: UInt64.max,
      produceSavePointRange: produceSavePointRange,
      isScalarSemantics: isScalarSemantics
    ) { currentPosition, end, isScalarSemantics in
      matchASCIIBitset(
        asciiBitset,
        at: currentPosition,
        limitedBy: end,
        isScalarSemantics: isScalarSemantics)
    }
  }
  internal func matchOneOrMoreASCIIBitset(
    _ asciiBitset: ASCIIBitset,
    at currentPosition: Index,
    limitedBy end: Index,
    produceSavePointRange: Bool,
    isScalarSemantics: Bool
  ) -> (next: Index, savePointRange: Range<Index>?)? {
    _runQuantLoop(
      at: currentPosition,
      limitedBy: end,
      minMatches: 1,
      maxMatches: UInt64.max,
      produceSavePointRange: produceSavePointRange,
      isScalarSemantics: isScalarSemantics
    ) { currentPosition, end, isScalarSemantics in
      matchASCIIBitset(
        asciiBitset,
        at: currentPosition,
        limitedBy: end,
        isScalarSemantics: isScalarSemantics)
    }
  }

  internal func matchQuantifiedASCIIBitset(
    _ asciiBitset: ASCIIBitset,
    at currentPosition: Index,
    limitedBy end: Index,
    minMatches: UInt64,
    maxMatches: UInt64,
    produceSavePointRange: Bool,
    isScalarSemantics: Bool
  ) -> (next: Index, savePointRange: Range<Index>?)? {
    _runQuantLoop(
      at: currentPosition,
      limitedBy: end,
      minMatches: minMatches,
      maxMatches: maxMatches,
      produceSavePointRange: produceSavePointRange,
      isScalarSemantics: isScalarSemantics
    ) { currentPosition, end, isScalarSemantics in
      matchASCIIBitset(
        asciiBitset,
        at: currentPosition,
        limitedBy: end,
        isScalarSemantics: isScalarSemantics)
    }
  }

  internal func matchZeroOrMoreScalar(
    _ scalar: Unicode.Scalar,
    at currentPosition: Index,
    limitedBy end: Index,
    produceSavePointRange: Bool,
    isScalarSemantics: Bool
  ) -> (next: Index, savePointRange: Range<Index>?)? {
    _runQuantLoop(
      at: currentPosition,
      limitedBy: end,
      minMatches: 0,
      maxMatches: UInt64.max,
      produceSavePointRange: produceSavePointRange,
      isScalarSemantics: isScalarSemantics
    ) { currentPosition, end, isScalarSemantics in
      matchScalar(
        scalar,
        at: currentPosition,
        limitedBy: end,
        boundaryCheck: !isScalarSemantics,
        isCaseInsensitive: false)
    }
  }
  internal func matchOneOrMoreScalar(
    _ scalar: Unicode.Scalar,
    at currentPosition: Index,
    limitedBy end: Index,
    produceSavePointRange: Bool,
    isScalarSemantics: Bool
  ) -> (next: Index, savePointRange: Range<Index>?)? {
    _runQuantLoop(
      at: currentPosition,
      limitedBy: end,
      minMatches: 1,
      maxMatches: UInt64.max,
      produceSavePointRange: produceSavePointRange,
      isScalarSemantics: isScalarSemantics
    ) { currentPosition, end, isScalarSemantics in
      matchScalar(
        scalar,
        at: currentPosition,
        limitedBy: end,
        boundaryCheck: !isScalarSemantics,
        isCaseInsensitive: false)

    }
  }

  internal func matchQuantifiedScalar(
    _ scalar: Unicode.Scalar,
    at currentPosition: Index,
    limitedBy end: Index,
    minMatches: UInt64,
    maxMatches: UInt64,
    produceSavePointRange: Bool,
    isScalarSemantics: Bool
  ) -> (next: Index, savePointRange: Range<Index>?)? {
    _runQuantLoop(
      at: currentPosition,
      limitedBy: end,
      minMatches: minMatches,
      maxMatches: maxMatches,
      produceSavePointRange: produceSavePointRange,
      isScalarSemantics: isScalarSemantics
    ) { currentPosition, end, isScalarSemantics in
      matchScalar(
        scalar,
        at: currentPosition,
        limitedBy: end,
        boundaryCheck: !isScalarSemantics,
        isCaseInsensitive: false)

    }
  }

  internal func matchZeroOrMoreBuiltinCC(
    _ builtinCC: _CharacterClassModel.Representation,
    at currentPosition: Index,
    limitedBy end: Index,
    produceSavePointRange: Bool,
    isInverted: Bool,
    isStrictASCII: Bool,
    isScalarSemantics: Bool
  ) -> (next: Index, savePointRange: Range<Index>?)? {
    _runQuantLoop(
      at: currentPosition,
      limitedBy: end,
      minMatches: 0,
      maxMatches: UInt64.max,
      produceSavePointRange: produceSavePointRange,
      isScalarSemantics: isScalarSemantics
    ) { currentPosition, end, isScalarSemantics in
      matchBuiltinCC(
        builtinCC,
        at: currentPosition,
        limitedBy: end,
        isInverted: isInverted,
        isStrictASCII: isStrictASCII,
        isScalarSemantics: isScalarSemantics)
    }
  }
  internal func matchOneOrMoreBuiltinCC(
    _ builtinCC: _CharacterClassModel.Representation,
    at currentPosition: Index,
    limitedBy end: Index,
    produceSavePointRange: Bool,
    isInverted: Bool,
    isStrictASCII: Bool,
    isScalarSemantics: Bool
  ) -> (next: Index, savePointRange: Range<Index>?)? {
    print(self[currentPosition])

    return _runQuantLoop(
      at: currentPosition,
      limitedBy: end,
      minMatches: 1,
      maxMatches: UInt64.max,
      produceSavePointRange: produceSavePointRange,
      isScalarSemantics: isScalarSemantics
    ) { currentPosition, end, isScalarSemantics in
      matchBuiltinCC(
        builtinCC,
        at: currentPosition,
        limitedBy: end,
        isInverted: isInverted,
        isStrictASCII: isStrictASCII,
        isScalarSemantics: isScalarSemantics)
    }
  }

  internal func matchQuantifiedBuiltinCC(
    _ builtinCC: _CharacterClassModel.Representation,
    at currentPosition: Index,
    limitedBy end: Index,
    minMatches: UInt64,
    maxMatches: UInt64,
    produceSavePointRange: Bool,
    isInverted: Bool,
    isStrictASCII: Bool,
    isScalarSemantics: Bool
  ) -> (next: Index, savePointRange: Range<Index>?)? {
    _runQuantLoop(
      at: currentPosition,
      limitedBy: end,
      minMatches: minMatches,
      maxMatches: maxMatches,
      produceSavePointRange: produceSavePointRange,
      isScalarSemantics: isScalarSemantics
    ) { currentPosition, end, isScalarSemantics in
      matchBuiltinCC(
        builtinCC,
        at: currentPosition,
        limitedBy: end,
        isInverted: isInverted,
        isStrictASCII: isStrictASCII,
        isScalarSemantics: isScalarSemantics)
    }
  }

  internal func matchZeroOrMoreRegexDot(
    at currentPosition: Index,
    limitedBy end: Index,
    produceSavePointRange: Bool,
    anyMatchesNewline: Bool,
    isScalarSemantics: Bool
  ) -> (next: Index, savePointRange: Range<Index>?)? {
    _runQuantLoop(
      at: currentPosition,
      limitedBy: end,
      minMatches: 0,
      maxMatches: UInt64.max,
      produceSavePointRange: produceSavePointRange,
      isScalarSemantics: isScalarSemantics
    ) { currentPosition, end, isScalarSemantics in
      matchRegexDot(
        at: currentPosition,
        limitedBy: end,
        anyMatchesNewline: anyMatchesNewline,
        isScalarSemantics: isScalarSemantics)
    }
  }
  internal func matchOneOrMoreRegexDot(
    at currentPosition: Index,
    limitedBy end: Index,
    produceSavePointRange: Bool,
    anyMatchesNewline: Bool,
    isScalarSemantics: Bool
  ) -> (next: Index, savePointRange: Range<Index>?)? {
    _runQuantLoop(
      at: currentPosition,
      limitedBy: end,
      minMatches: 1,
      maxMatches: UInt64.max,
      produceSavePointRange: produceSavePointRange,
      isScalarSemantics: isScalarSemantics
    ) { currentPosition, end, isScalarSemantics in
      matchRegexDot(
        at: currentPosition,
        limitedBy: end,
        anyMatchesNewline: anyMatchesNewline,
        isScalarSemantics: isScalarSemantics)
    }
  }

  internal func matchQuantifiedRegexDot(
    at currentPosition: Index,
    limitedBy end: Index,
    minMatches: UInt64,
    maxMatches: UInt64,
    produceSavePointRange: Bool,
    anyMatchesNewline: Bool,
    isScalarSemantics: Bool
  ) -> (next: Index, savePointRange: Range<Index>?)? {
    _runQuantLoop(
      at: currentPosition,
      limitedBy: end,
      minMatches: minMatches,
      maxMatches: maxMatches,
      produceSavePointRange: produceSavePointRange,
      isScalarSemantics: isScalarSemantics
    ) { currentPosition, end, isScalarSemantics in
      matchRegexDot(
        at: currentPosition,
        limitedBy: end,
        anyMatchesNewline: anyMatchesNewline,
        isScalarSemantics: isScalarSemantics)
    }
  }
}


// MARK: - Matchers

extension UTF8Span {
  func match(
    _ char: Character,
    at pos: Index,
    limitedBy end: Index,
    isCaseInsensitive: Bool
  ) -> Index? {
    // TODO: This can be greatly sped up with string internals
    // TODO: This is also very much quick-check-able
    guard let (stringChar, next) = characterAndEnd(at: pos, limitedBy: end)
    else { return nil }

    if isCaseInsensitive {
      guard stringChar.lowercased() == char.lowercased() else { return nil }
    } else {
      guard stringChar == char else { return nil }
    }

    return next
  }

  func matchSeq(
    _ seq: Substring,
    at pos: Index,
    limitedBy end: Index,
    isScalarSemantics: Bool
  ) -> Index? {
    // TODO: This can be greatly sped up with string internals
    // TODO: This is also very much quick-check-able
    var cur = pos

    if isScalarSemantics {
      for e in seq.unicodeScalars {
        guard cur < end, unicodeScalars[cur] == e else { return nil }
        self.unicodeScalars.formIndex(after: &cur)
      }
    } else {
      for e in seq {
        guard let (char, next) = characterAndEnd(at: cur, limitedBy: end),
              char == e
        else { return nil }
        cur = next
      }
    }

    guard cur <= end else { return nil }
    return cur
  }

  func matchScalar(
    _ scalar: Unicode.Scalar,
    at pos: Index,
    limitedBy end: Index,
    boundaryCheck: Bool,
    isCaseInsensitive: Bool
  ) -> Index? {
    // TODO: extremely quick-check-able
    // TODO: can be sped up with string internals
    guard pos < end else { return nil }
    let curScalar = unicodeScalars[pos]

    if isCaseInsensitive {
      guard curScalar.properties.lowercaseMapping == scalar.properties.lowercaseMapping
      else {
        return nil
      }
    } else {
      guard curScalar == scalar else { return nil }
    }

    let idx = unicodeScalars.index(after: pos)
    assert(idx <= end, "Input is a substring with a sub-scalar endIndex.")

    if boundaryCheck && !isOnGraphemeClusterBoundary(idx) {
      return nil
    }

    return idx
  }

  func matchASCIIBitset(
    _ bitset: DSLTree.CustomCharacterClass.AsciiBitset,
    at pos: Index,
    limitedBy end: Index,
    isScalarSemantics: Bool
  ) -> Index? {

    // FIXME: Inversion should be tracked and handled in only one place.
    // That is, we should probably store it as a bit in the instruction, so that
    // bitset matching and bitset inversion is bit-based rather that semantically
    // inverting the notion of a match or not. As-is, we need to track both
    // meanings in some code paths.
    let isInverted = bitset.isInverted

    // TODO: More fodder for refactoring `_quickASCIICharacter`, see the comment
    // there
    guard let (asciiByte, next, isCRLF) = _quickASCIICharacter(
      at: pos,
      limitedBy: end
    ) else {
      if isScalarSemantics {
        guard pos < end else { return nil }
        guard bitset.matches(unicodeScalars[pos]) else { return nil }
        return unicodeScalars.index(after: pos)
      } else {
        guard let (char, next) = characterAndEnd(at: pos, limitedBy: end),
              bitset.matches(char) else { return nil }
        return next
      }
    }

    guard bitset.matches(asciiByte) else {
      // FIXME: check inversion here after refactored out of bitset
      return nil
    }

    // CR-LF should only match `[\r]` in scalar semantic mode or if inverted
    if isCRLF {
      if isScalarSemantics {
        return self.unicodeScalars.index(before: next)
      }
      if isInverted {
        return next
      }
      return nil
    }

    return next
  }
}

// MARK: - MEBuiltins

extension UTF8Span {
  /// Returns the character at `pos`, bounded by `end`, as well as the upper
  /// boundary of the returned character.
  ///
  /// This function handles loading a character from a string while respecting
  /// an end boundary, even if that end boundary is sub-character or sub-scalar.
  ///
  ///   - If `pos` is at or past `end`, this function returns `nil`.
  ///   - If `end` is between `pos` and the next grapheme cluster boundary (i.e.,
  ///     `end` is before `self.index(after: pos)`, then the returned character
  ///     is smaller than the one that would be produced by `self[pos]` and the
  ///     returned index is at the end of that character.
  ///   - If `end` is between `pos` and the next grapheme cluster boundary, and
  ///     is not on a Unicode scalar boundary, the partial scalar is dropped. This
  ///     can result in a `nil` return or a character that includes only part of
  ///     the `self[pos]` character.
  ///
  /// - Parameters:
  ///   - pos: The position to load a character from.
  ///   - end: The limit for the character at `pos`.
  /// - Returns: The character at `pos`, bounded by `end`, if it exists, along
  ///   with the upper bound of that character. The upper bound is always
  ///   scalar-aligned.
  func characterAndEnd(at pos: Index, limitedBy end: Index) -> (Character, Index)? {
    // FIXME: Sink into the stdlib to avoid multiple boundary calculations
    guard pos < end else { return nil }
    let next = characters.index(after: pos)
    if next <= end {
      return (characters[pos], next)
    }

    // `end` must be a sub-character position that is between `pos` and the
    // next grapheme boundary. This is okay if `end` is on a Unicode scalar
    // boundary, but if it's in the middle of a scalar's code units, there
    // may not be a character to return at all after rounding down. Use
    // `Substring`'s rounding to determine what we can return.
    let substr = self[pos..<end]
    return substr.isEmpty
      ? nil
    : (substr.characters.first!, substr.characters.endIndex)
  }

  func matchAnyNonNewline(
    at currentPosition: Index,
    limitedBy end: Index,
    isScalarSemantics: Bool
  ) -> Index? {
    guard currentPosition < end else { return nil }
    if case .definite(let result) = _quickMatchAnyNonNewline(
      at: currentPosition,
      limitedBy: end,
      isScalarSemantics: isScalarSemantics
    ) {
      assert(result == _thoroughMatchAnyNonNewline(
        at: currentPosition,
        limitedBy: end,
        isScalarSemantics: isScalarSemantics))
      return result
    }
    return _thoroughMatchAnyNonNewline(
      at: currentPosition,
      limitedBy: end,
      isScalarSemantics: isScalarSemantics)
  }

  @inline(__always)
  private func _quickMatchAnyNonNewline(
    at currentPosition: Index,
    limitedBy end: Index,
    isScalarSemantics: Bool
  ) -> QuickResult<Index?> {
    assert(currentPosition < end)
    guard let (asciiValue, next, isCRLF) = _quickASCIICharacter(
      at: currentPosition, limitedBy: end
    ) else {
      return .unknown
    }
    switch asciiValue {
    case (._lineFeed)...(._carriageReturn):
      return .definite(nil)
    default:
      assert(!isCRLF)
      return .definite(next)
    }
  }

  @inline(never)
  private func _thoroughMatchAnyNonNewline(
    at currentPosition: Index,
    limitedBy end: Index,
    isScalarSemantics: Bool
  ) -> Index? {
    if isScalarSemantics {
      guard currentPosition < end else { return nil }
      let scalar = unicodeScalars[currentPosition]
      guard !scalar.isNewline else { return nil }
      return unicodeScalars.index(after: currentPosition)
    }

    guard let (char, next) = characterAndEnd(at: currentPosition, limitedBy: end),
          !char.isNewline
    else { return nil }
    return next
  }

  internal func matchRegexDot(
    at currentPosition: Index,
    limitedBy end: Index,
    anyMatchesNewline: Bool,
    isScalarSemantics: Bool
  ) -> Index? {
    guard currentPosition < end else { return nil }

    if anyMatchesNewline {
      return index(
        after: currentPosition, isScalarSemantics: isScalarSemantics)
    }

    return matchAnyNonNewline(
      at: currentPosition,
      limitedBy: end,
      isScalarSemantics: isScalarSemantics)
  }
}

// MARK: - Built-in character class matching
extension UTF8Span {
  // Mentioned in ProgrammersManual.md, update docs if redesigned
  func matchBuiltinCC(
    _ cc: _CharacterClassModel.Representation,
    at currentPosition: Index,
    limitedBy end: Index,
    isInverted: Bool,
    isStrictASCII: Bool,
    isScalarSemantics: Bool
  ) -> Index? {
    guard currentPosition < end else { return nil }
    if case .definite(let result) = _quickMatchBuiltinCC(
      cc,
      at: currentPosition,
      limitedBy: end,
      isInverted: isInverted,
      isStrictASCII: isStrictASCII,
      isScalarSemantics: isScalarSemantics
    ) {
      assert(result == _thoroughMatchBuiltinCC(
        cc,
        at: currentPosition,
        limitedBy: end,
        isInverted: isInverted,
        isStrictASCII: isStrictASCII,
        isScalarSemantics: isScalarSemantics))
      return result
    }
    return _thoroughMatchBuiltinCC(
      cc,
      at: currentPosition,
      limitedBy: end,
      isInverted: isInverted,
      isStrictASCII: isStrictASCII,
      isScalarSemantics: isScalarSemantics)
  }

  // Mentioned in ProgrammersManual.md, update docs if redesigned
  @inline(__always)
  private func _quickMatchBuiltinCC(
    _ cc: _CharacterClassModel.Representation,
    at currentPosition: Index,
    limitedBy end: Index,
    isInverted: Bool,
    isStrictASCII: Bool,
    isScalarSemantics: Bool
  ) -> QuickResult<Index?> {
    assert(currentPosition < end)
    guard let (next, result) = _quickMatch(
      cc,
      at: currentPosition,
      limitedBy: end,
      isScalarSemantics: isScalarSemantics
    ) else {
      return .unknown
    }
    return .definite(result == isInverted ? nil : next)
  }

  // Mentioned in ProgrammersManual.md, update docs if redesigned
  @inline(never)
  private func _thoroughMatchBuiltinCC(
    _ cc: _CharacterClassModel.Representation,
    at currentPosition: Index,
    limitedBy end: Index,
    isInverted: Bool,
    isStrictASCII: Bool,
    isScalarSemantics: Bool
  ) -> Index? {
    // TODO: Branch here on scalar semantics
    // Don't want to pay character cost if unnecessary
    guard let (char, nextIndex) =
            characterAndEnd(at: currentPosition, limitedBy: end)
    else { return nil }
    var next = nextIndex
    let scalar = unicodeScalars[currentPosition]

    let asciiCheck = !isStrictASCII
    || (scalar.isASCII && isScalarSemantics)
    || char.isASCII

    var matched: Bool
    if isScalarSemantics && cc != .anyGrapheme {
      next = unicodeScalars.index(after: currentPosition)
    }

    switch cc {
    case .any, .anyGrapheme:
      matched = true
    case .digit:
      if isScalarSemantics {
        matched = scalar.properties.numericType != nil && asciiCheck
      } else {
        matched = char.isNumber && asciiCheck
      }
    case .horizontalWhitespace:
      if isScalarSemantics {
        matched = scalar.isHorizontalWhitespace && asciiCheck
      } else {
        matched = char._isHorizontalWhitespace && asciiCheck
      }
    case .verticalWhitespace:
      if isScalarSemantics {
        matched = scalar.isNewline && asciiCheck
      } else {
        matched = char._isNewline && asciiCheck
      }
    case .newlineSequence:
      if isScalarSemantics {
        matched = scalar.isNewline && asciiCheck
        if matched && scalar == "\r"
            && next < end && unicodeScalars[next] == "\n" {
          // Match a full CR-LF sequence even in scalar semantics
          unicodeScalars.formIndex(after: &next)
        }
      } else {
        matched = char._isNewline && asciiCheck
      }
    case .whitespace:
      if isScalarSemantics {
        matched = scalar.properties.isWhitespace && asciiCheck
      } else {
        matched = char.isWhitespace && asciiCheck
      }
    case .word:
      if isScalarSemantics {
        matched = scalar.properties.isAlphabetic && asciiCheck
      } else {
        matched = char.isWordCharacter && asciiCheck
      }
    }

    if isInverted {
      matched.toggle()
    }

    guard matched else {
      return nil
    }
    return next
  }
}

// MARK: - ASCII

extension UTF8Span {
  /// TODO: better to take isScalarSemantics parameter, we can return more results
  /// and we can give the right `next` index, not requiring the caller to re-adjust it
  /// TODO: detailed description of nuanced semantics
  func _quickASCIICharacter(
    at idx: Index,
    limitedBy end: Index
  ) -> (first: UInt8, next: Index, crLF: Bool)? {
    // TODO: fastUTF8 version
//    assert(String.Index(idx, within: unicodeScalars) != nil)
    assert(idx <= end)

    if idx == end {
      return nil
    }
    let base = utf8[idx]
    guard base._isASCII else {
      assert(!characters[idx].isASCII)
      return nil
    }

    var next = utf8.index(after: idx)
    if next == end {
      return (first: base, next: next, crLF: false)
    }

    let tail = utf8[next]
    guard tail._isSub300StartingByte else { return nil }

    // Handle CR-LF:
    if base == ._carriageReturn && tail == ._lineFeed {
      utf8.formIndex(after: &next)
      guard next == end || utf8[next]._isSub300StartingByte else {
        return nil
      }
      return (first: base, next: next, crLF: true)
    }

    assert(characters[idx].isASCII && characters[idx] != "\r\n")
    return (first: base, next: next, crLF: false)
  }

  func _quickMatch(
    _ cc: _CharacterClassModel.Representation,
    at idx: Index,
    limitedBy end: Index,
    isScalarSemantics: Bool
  ) -> (next: Index, matchResult: Bool)? {
    /// ASCII fast-paths
    guard let (asciiValue, next, isCRLF) = _quickASCIICharacter(
      at: idx, limitedBy: end
    ) else {
      return nil
    }

    // TODO: bitvectors
    switch cc {
    case .any, .anyGrapheme:
      return (next, true)

    case .digit:
      return (next, asciiValue._asciiIsDigit)

    case .horizontalWhitespace:
      return (next, asciiValue._asciiIsHorizontalWhitespace)

    case .verticalWhitespace, .newlineSequence:
      if asciiValue._asciiIsVerticalWhitespace {
        if isScalarSemantics && isCRLF && cc == .verticalWhitespace {
          return (utf8.index(before: next), true)
        }
        return (next, true)
      }
      return (next, false)

    case .whitespace:
      if asciiValue._asciiIsWhitespace {
        if isScalarSemantics && isCRLF {
          return (utf8.index(before: next), true)
        }
        return (next, true)
      }
      return (next, false)

    case .word:
      return (next, asciiValue._asciiIsWord)
    }
  }

}

