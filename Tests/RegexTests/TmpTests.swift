import XCTest
import _StringProcessing

class TmpTests: XCTestCase {
  func testFoo() {
    let str = "abcdefg"
    let span = str.utf8Span
    print(span[0])
    
  }
}
