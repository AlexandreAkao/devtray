import XCTest
@testable import DevTrayCore

final class PreloadBusTests: XCTestCase {
    func test_initialState_pendingIsNil() {
        let bus = PreloadBus()
        XCTAssertNil(bus.pending)
    }

    func test_send_setsPending() {
        let bus = PreloadBus()
        let payload = PreloadPayload(toolID: "jwt", text: "eyJ.x.y")
        bus.send(payload)
        XCTAssertEqual(bus.pending, payload)
    }

    func test_consume_clearsPendingAndReturnsIt() {
        let bus = PreloadBus()
        let payload = PreloadPayload(toolID: "json", text: nil)
        bus.send(payload)
        let consumed = bus.consume()
        XCTAssertEqual(consumed, payload)
        XCTAssertNil(bus.pending)
    }

    func test_consumeWithNoPending_returnsNil() {
        let bus = PreloadBus()
        XCTAssertNil(bus.consume())
    }

    func test_sendOverwritesPriorPending() {
        let bus = PreloadBus()
        bus.send(PreloadPayload(toolID: "jwt", text: "a"))
        bus.send(PreloadPayload(toolID: "url", text: "https://x"))
        XCTAssertEqual(bus.pending?.toolID, "url")
    }
}
