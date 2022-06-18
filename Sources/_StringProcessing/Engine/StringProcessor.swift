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

struct StringProcessor {
  typealias Position = String.Index

  let input: String

  let subjectBounds: Range<Position>

  let matchMode: MatchMode

  let instructions: InstructionList<Instruction>

  // MARK: Resettable state

  var searchBounds: Range<Position>

  var currentPosition: Position

  var controller: Controller

  var registers: Processor<String>.Registers

  var savePoints: [SavePoint] = []

  var callStack: [InstructionAddress] = []

  var storedCaptures: Array<Processor<String>._StoredCapture>

  var state: State = .inProgress

  var failureReason: Error? = nil


  // MARK: Metrics, debugging, etc.
  var cycleCount = 0
  var isTracingEnabled: Bool

}

extension StringProcessor {
  // FIXME: Goes away when we fix subject / search bounds issues
  var bounds: Range<Position> {
    get { searchBounds }
    set { self.searchBounds = newValue }
  }
  var start: Position { bounds.lowerBound }
  var end: Position { bounds.upperBound }
}

extension StringProcessor {
  init(
    program: Program,
    input: String,
    bounds: Range<Position>,
    matchMode: MatchMode,
    isTracingEnabled: Bool
  ) {
    self.controller = Controller(pc: 0)
    self.instructions = program.instructions
    self.input = input

    // FIXME
    self.subjectBounds = bounds
    self.searchBounds = bounds

    self.matchMode = matchMode
    self.isTracingEnabled = isTracingEnabled
    self.currentPosition = bounds.lowerBound

    self.registers = Processor<String>.Registers(program, bounds.upperBound)
    self.storedCaptures = Array(
       repeating: .init(), count: program.registerInfo.captures)

    _checkInvariants()
  }


  mutating func reset(searchBounds: Range<Position>) {
    // FIXME: We currently conflate both subject bounds and search bounds
    // This should just reset search bounds
    self.bounds = searchBounds
    self.currentPosition = self.bounds.lowerBound

    self.controller = Controller(pc: 0)

    self.registers.reset(sentinel: bounds.upperBound)

    self.savePoints.removeAll(keepingCapacity: true)
    self.callStack.removeAll(keepingCapacity: true)

    for idx in storedCaptures.indices {
      storedCaptures[idx] = .init()
    }

    self.state = .inProgress
    self.failureReason = nil

    _checkInvariants()
  }

  func _checkInvariants() {
    assert(end <= input.endIndex)
    assert(start >= input.startIndex)
    assert(currentPosition >= start)
    assert(currentPosition <= end)
  }
}

extension StringProcessor {
  var slice: Substring {
    // TODO: Should we whole-scale switch to slices, or
    // does that depend on options for some anchors?
    input[bounds]
  }

  // Advance in our input, without any checks or failure signalling
  mutating func _uncheckedForcedConsumeOne() {
    assert(currentPosition != end)
    input.formIndex(after: &currentPosition)
  }

  // Advance in our input
  //
  // Returns whether the advance succeeded. On failure, our
  // save point was restored
  mutating func consume(_ n: Distance) -> Bool {
    guard let idx = input.index(
      currentPosition, offsetBy: n.rawValue, limitedBy: end
    ) else {
      signalFailure()
      return false
    }
    currentPosition = idx
    return true
  }

  mutating func advance(to nextIndex: Position) {
    assert(nextIndex >= bounds.lowerBound)
    assert(nextIndex <= bounds.upperBound)
    assert(nextIndex > currentPosition)
    currentPosition = nextIndex
  }

  func doPrint(_ s: String) {
    var enablePrinting: Bool { false }
    if enablePrinting {
      print(s)
    }
  }

  func load() -> Character? {
    currentPosition < end ? input[currentPosition] : nil
  }
  func load(count: Int) -> Substring? {
    let slice = self.slice[currentPosition...].prefix(count)
    guard slice.count == count else { return nil }
    return slice
  }

  // Match against the current input element. Returns whether
  // it succeeded vs signaling an error.
  mutating func match(_ e: Character) -> Bool {
    guard let cur = load(), cur == e else {
      signalFailure()
      return false
    }
    _uncheckedForcedConsumeOne()
    return true
  }

  // Match against the current input prefix. Returns whether
  // it succeeded vs signaling an error.
  mutating func matchSeq<C: Collection>(
    _ seq: C
  ) -> Bool where C.Element == Character {
    for e in seq {
      guard match(e) else { return false }
    }
    return true
  }

  mutating func signalFailure() {
    guard let (pc, pos, stackEnd, capEnds, intRegisters) =
            savePoints.popLast()?.destructure
    else {
      state = .fail
      return
    }
    assert(stackEnd.rawValue <= callStack.count)
    assert(capEnds.count == storedCaptures.count)

    controller.pc = pc
    currentPosition = pos ?? currentPosition
    callStack.removeLast(callStack.count - stackEnd.rawValue)
    storedCaptures = capEnds
    registers.ints = intRegisters
  }

  mutating func abort(_ e: Error? = nil) {
    if let e = e {
      self.failureReason = e
    }
    self.state = .fail
  }

  mutating func tryAccept() {
    switch (currentPosition, matchMode) {
    // When reaching the end of the match bounds or when we are only doing a
    // prefix match, transition to accept.
    case (bounds.upperBound, _), (_, .partialFromFront):
      state = .accept

    // When we are doing a full match but did not reach the end of the match
    // bounds, backtrack if possible.
    case (_, .wholeString):
      signalFailure()
    }
  }

  mutating func cycle() {
    _checkInvariants()
    assert(state == .inProgress)
    if cycleCount == 0 { trace() }
    defer {
      cycleCount += 1
      trace()
      _checkInvariants()
    }
    let (opcode, payload) = fetch().destructure

    switch opcode {
    case .invalid:
      fatalError("Invalid program")
    case .nop:
      if checkComments,
         let s = payload.optionalString
      {
        doPrint(registers[s])
      }
      controller.step()

    case .decrement:
      let (bool, int) = payload.pairedBoolInt
      let newValue = registers[int] - 1
      registers[bool] = newValue == 0
      registers[int] = newValue
      controller.step()

    case .moveImmediate:
      let (imm, reg) = payload.pairedImmediateInt
      let int = Int(asserting: imm)
      assert(int == imm)

      registers[reg] = int
      controller.step()

    case .movePosition:
      let reg = payload.position
      registers[reg] = currentPosition
      controller.step()

    case .branch:
      controller.pc = payload.addr

    case .condBranch:
      let (addr, cond) = payload.pairedAddrBool
      if registers[cond] {
        controller.pc = addr
      } else {
        controller.step()
      }

    case .condBranchZeroElseDecrement:
      let (addr, int) = payload.pairedAddrInt
      if registers[int] == 0 {
        controller.pc = addr
      } else {
        registers[int] -= 1
        controller.step()
      }

    case .save:
      let resumeAddr = payload.addr
      let sp = makeSavePoint(resumeAddr)
      savePoints.append(sp)
      controller.step()

    case .saveAddress:
      let resumeAddr = payload.addr
      let sp = makeSavePoint(resumeAddr, addressOnly: true)
      savePoints.append(sp)
      controller.step()

    case .splitSaving:
      let (nextPC, resumeAddr) = payload.pairedAddrAddr
      let sp = makeSavePoint(resumeAddr)
      savePoints.append(sp)
      controller.pc = nextPC

    case .clear:
      if let _ = savePoints.popLast() {
        controller.step()
      } else {
        fatalError("TODO: What should we do here?")
      }

    case .peek:
      fatalError()

    case .restore:
      signalFailure()

    case .push:
      fatalError()

    case .pop:
      fatalError()

    case .call:
      controller.step()
      callStack.append(controller.pc)
      controller.pc = payload.addr

    case .ret:
      // TODO: Should empty stack mean success?
      guard let r = callStack.popLast() else {
        tryAccept()
        return
      }
      controller.pc = r

    case .abort:
      // TODO: throw or otherwise propagate
      if let s = payload.optionalString {
        doPrint(registers[s])
      }
      state = .fail

    case .accept:
      tryAccept()

    case .fail:
      signalFailure()

    case .advance:
      if consume(payload.distance) {
        controller.step()
      }

    case .match:
      let reg = payload.element
      if match(registers[reg]) {
        controller.step()
      }

    case .matchSequence:
      let reg = payload.sequence
      let seq = registers[reg]
      if matchSeq(seq) {
        controller.step()
      }

    case .matchSlice:
      let (lower, upper) = payload.pairedPosPos
      let range = registers[lower]..<registers[upper]
      let slice = input[range]
      if matchSeq(slice) {
        controller.step()
      }

    case .consumeBy:
      let reg = payload.consumer
      guard currentPosition < bounds.upperBound,
            let nextIndex = registers[reg](
              input, currentPosition..<bounds.upperBound)
      else {
        signalFailure()
        return
      }
      advance(to: nextIndex)
      controller.step()

    case .assertBy:
      let reg = payload.assertion
      let assertion = registers[reg]
      do {
        guard try assertion(input, currentPosition, bounds) else {
          signalFailure()
          return
        }
      } catch {
        abort(error)
        return
      }
      controller.step()

    case .matchBy:
      let (matcherReg, valReg) = payload.pairedMatcherValue
      let matcher = registers[matcherReg]
      do {
        guard let (nextIdx, val) = try matcher(
          input, currentPosition, bounds
        ) else {
          signalFailure()
          return
        }
        registers[valReg] = val
        advance(to: nextIdx)
        controller.step()
      } catch {
        abort(error)
        return
      }

    case .print:
      // TODO: Debug stream
      doPrint(registers[payload.string])

    case .assertion:
      let (element, cond) =
        payload.pairedElementBool
      let result: Bool
      if let cur = load(), cur == registers[element] {
        result = true
      } else {
        result = false
      }
      registers[cond] = result
      controller.step()

    case .backreference:
      let capNum = Int(
        asserting: payload.capture.rawValue)
      guard capNum < storedCaptures.count else {
        fatalError("Should this be an assert?")
      }
      // TODO:
      //   Should we assert it's not finished yet?
      //   What's the behavior there?
      let cap = storedCaptures[capNum]
      guard let range = cap.range else {
        signalFailure()
        return
      }
      if matchSeq(input[range]) {
        controller.step()
      }

    case .beginCapture:
      let capNum = Int(
        asserting: payload.capture.rawValue)

       storedCaptures[capNum].startCapture(currentPosition)
       controller.step()

     case .endCapture:
      let capNum = Int(
        asserting: payload.capture.rawValue)

       storedCaptures[capNum].endCapture(currentPosition)
       controller.step()

    case .transformCapture:
      let (cap, trans) = payload.pairedCaptureTransform
      let transform = registers[trans]
      let capNum = Int(asserting: cap.rawValue)

      do {
        // FIXME: Pass input or the slice?
        guard let value = try transform(input, storedCaptures[capNum]) else {
          signalFailure()
          return
        }
        storedCaptures[capNum].registerValue(value)
        controller.step()
      } catch {
        abort(error)
        return
      }

    case .captureValue:
      let (val, cap) = payload.pairedValueCapture
      let value = registers[val]
      let capNum = Int(asserting: cap.rawValue)
      let sp = makeSavePoint(self.currentPC)
      storedCaptures[capNum].registerValue(
        value, overwriteInitial: sp)
      controller.step()
    }

  }
}

// MARK: - ...


extension StringProcessor: TracedProcessor {
  var isFailState: Bool { state == .fail }
  var isAcceptState: Bool { state == .accept }

  var currentPC: InstructionAddress { controller.pc }

  func formatSavePoints() -> String {
    if !savePoints.isEmpty {
      var result = "save points:\n"
      for point in savePoints {
        result += "  \(point.describe(in: input))\n"
      }
      return result
    }
    return ""
  }
}

extension StringProcessor {

  // TODO: What all do we want to save? Configurable?
  // TODO: Do we need to save any registers?
  // TODO: Is this the right place to do function stack unwinding?
  struct SavePoint {
    var pc: InstructionAddress
    var pos: Position?

    // The end of the call stack, so we can slice it off
    // when failing inside a call.
    //
    // NOTE: Alternatively, also place return addresses on the
    // save point stack
    var stackEnd: CallStackAddress

    // FIXME: Save minimal info (e.g. stack position and
    // perhaps current start)
    var captureEnds: [_StoredCapture]

    // The int registers store values that can be relevant to
    // backtracking, such as the number of trips in a quantification.
    var intRegisters: [Int]

    var destructure: (
      pc: InstructionAddress,
      pos: Position?,
      stackEnd: CallStackAddress,
      captureEnds: [_StoredCapture],
      intRegisters: [Int]
    ) {
      (pc, pos, stackEnd, captureEnds, intRegisters)
    }
  }

  func makeSavePoint(
    _ pc: InstructionAddress,
    addressOnly: Bool = false
  ) -> SavePoint {
    SavePoint(
      pc: pc,
      pos: addressOnly ? nil : currentPosition,
      stackEnd: .init(callStack.count),
      captureEnds: storedCaptures,
      intRegisters: registers.ints)
  }
}


