import CoreGraphics
import XCTest
@testable import phoneframes

final class CaptureTests: XCTestCase {
  func testCapturesOnlyWhenKnownUnlockedAndLit() {
    XCTAssertTrue(Capture.canCapture(power: ["Locked": false, "ScreenOn": true]))
    let idle: [[String: Any]] = [
      ["Locked": true, "ScreenOn": true], ["Locked": false, "ScreenOn": false],
      ["ScreenOn": true], ["Locked": false], [:], ["Locked": "false", "ScreenOn": 1],
    ]
    for state in idle { XCTAssertFalse(Capture.canCapture(power: state)) }
  }

  func testBacksOffAfterFailuresAndSlowCaptures() {
    XCTAssertEqual(Capture.pollDelay(interval: 1, elapsed: 8, failures: 1), 5)
    XCTAssertEqual(Capture.pollDelay(interval: 1, elapsed: 8, failures: 2), 10)
    XCTAssertEqual(Capture.pollDelay(interval: 1, elapsed: 8, failures: 4), 30)
    XCTAssertEqual(Capture.pollDelay(interval: 1, elapsed: 0.4, failures: 0), 0.6, accuracy: 0.001)
    XCTAssertEqual(Capture.pollDelay(interval: 1, elapsed: 4, failures: 0), 12)
    XCTAssertEqual(Capture.pollDelay(interval: 1, elapsed: 25, failures: 0), 15)
  }

  func testFrameIsHeaderThenBGRA() throws {
    let context = CGContext(data: nil, width: 2, height: 1, bitsPerComponent: 8, bytesPerRow: 8,
      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: 2, height: 1))
    let frame = try XCTUnwrap(Capture.encode(context.makeImage()!))
    XCTAssertEqual(frame.prefix(4), Data("2 1\n".utf8))
    XCTAssertEqual(frame.count, 4 + 8)
    XCTAssertEqual(Array(frame.suffix(8).prefix(3)), [0, 0, 255])
  }
}
