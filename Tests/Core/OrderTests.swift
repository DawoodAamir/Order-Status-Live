import XCTest

@testable import OrderCore

final class OrderTests: XCTestCase {
  func testStagesStopAtDelivered() {
    var order = Order()
    for _ in 0..<10 { order.advance() }
    XCTAssertEqual(order.stage, 4)
    XCTAssertEqual(order.revision, 4)
  }
  func testStaleAndUnrelatedUpdatesAreRejected() throws {
    var order = Order()
    order.advance()
    XCTAssertThrowsError(try order.accept(Order()))
    var other = order
    other.id = "other"
    XCTAssertThrowsError(try order.accept(other))
    var next = order
    next.advance()
    try order.accept(next)
    XCTAssertEqual(order.stage, 2)
  }
}
