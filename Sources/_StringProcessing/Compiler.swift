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
    let options = MatchingOptions()

    // TODO: Handle global options
    var codegen = ByteCodeGen(
      options: options, captureList: tree.root._captureList
    )
    try codegen.emitNode(tree.root)
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
