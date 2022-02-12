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

class Compiler {
  let tree: DSLTree

  // TODO: Or are these stored on the tree?
  var options = MatchingOptions()

  init(ast: AST) {
    self.tree = ast.dslTree
  }

  init(tree: DSLTree) {
    self.tree = tree
  }

  __consuming func emit() throws -> Program {
    // TODO: Handle global options
    var codegen = ByteCodeGen(options: options)
    codegen.builder.captureStructure = tree.captureStructure
    try codegen.emitNode(tree.root)
    let program = try codegen.finish()
    return program
  }
}

public func _compileRegex(
  _ regex: String, _ syntax: SyntaxOptions = .traditional
) throws -> Executor {
  let ast = try parse(regex, syntax)
  let program = try Compiler(ast: ast).emit()
  return Executor(program: program)
}

