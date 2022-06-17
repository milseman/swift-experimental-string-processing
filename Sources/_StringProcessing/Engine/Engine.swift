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

// Currently, engine binds the type and consume binds an instance.
// But, we can play around with this.
struct Engine<Input: BidirectionalCollection> where Input.Element: Hashable {

  var program: MEProgram<Input>

  // Whether the regex starts in grapheme-semantic mode, and thus all start
  // positions must be aligned.
  let graphemeAlignedStart: Bool

  // TODO: Pre-allocated register banks

  var instructions: InstructionList<Instruction> { program.instructions }

  var enableTracing: Bool {
    get { program.enableTracing }
    set { program.enableTracing = newValue }
  }

  init(
    _ program: MEProgram<Input>,
    enableTracing: Bool? = nil
  ) {
    var program = program
    if let t = enableTracing {
      program.enableTracing = t
    }
    self.program = program
    self.graphemeAlignedStart =
      program.initialOptions.semanticLevel == .graphemeCluster
  }
}

struct AsyncEngine { /* ... */ }

extension Engine: CustomStringConvertible {
  var description: String {
    // TODO: better description
    return program.description
  }
}
