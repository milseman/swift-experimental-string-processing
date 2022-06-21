

enum MECharacterClass: UInt64 {
  // TODO: all the character classes

  // TODO(performance): layout bits such that ASCII-only
  // appears as its own dedicated bit (thus ignorable by
  // ASCII fast path).
}

enum MEAssertion: UInt64 {
  // TODO: all the assertions and anchors

}


extension Processor {
  mutating func builtinAssertion() {
    fatalError("TODO: assertions and anchors")
  }

  mutating func builtinCharacterClass() {
    fatalError("TODO: character classes")
  }
}
