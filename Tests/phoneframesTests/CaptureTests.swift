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

  func testChecksALockedPhoneLessOftenAfterTheFirstMinute() {
    XCTAssertEqual(Capture.pausedDelay(interval: 1, polls: 1), 3)
    XCTAssertEqual(Capture.pausedDelay(interval: 1, polls: 20), 3)
    XCTAssertEqual(Capture.pausedDelay(interval: 1, polls: 21), 10)
    XCTAssertEqual(Capture.pausedDelay(interval: 30, polls: 21), 30)
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

  func testEncodeScalesDown() throws {
    let context = CGContext(data: nil, width: 10, height: 6, bitsPerComponent: 8, bytesPerRow: 40,
      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(red: 0, green: 1, blue: 0, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: 10, height: 6))
    let frame = try XCTUnwrap(Capture.encode(context.makeImage()!, scale: 0.5))
    XCTAssertEqual(frame.prefix(4), Data("5 3\n".utf8))
    XCTAssertEqual(frame.count, 4 + 5 * 3 * 4)
    XCTAssertEqual(Array(frame.suffix(5 * 3 * 4).prefix(3)), [0, 255, 0])
  }
}
