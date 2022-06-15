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

@_implementationOnly import _RegexParser

struct Compiler {
  static func compile(_ tree: DSLTree) throws -> Program {

    // FIXME: do options vary across iterations?

    // TODO: how should options be presented?
    var worklist = [(tree.root, MatchingOptions())]

    var codegen = ByteCodeGen()

    while let (node, opts) = worklist.popLast() {
      // TOOD: Should options flow in like this?

      codegen.options = opts
      try codegen.compileRootNode(node, opts)
    }

    let program = try codegen.finish()
    return program
  }
}

func _compileRegex(
  _ regex: String, _ syntax: SyntaxOptions = .traditional
) throws -> Executor {
  let ast = try parse(regex, .semantic, syntax)
  let program = try Compiler.compile(ast.dslTree)
  return Executor(program: program)
}

// An error produced when compiling a regular expression.
enum RegexCompilationError: Error, CustomStringConvertible {
  // TODO: Source location?
  case uncapturedReference

  var description: String {
    switch self {
    case .uncapturedReference:
      return "Found a reference used before it captured any match."
    }
  }
}
