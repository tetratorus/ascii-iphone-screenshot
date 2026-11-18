import CoreGraphics
import Foundation
import LightpinkyCore

/// Captures a paired iPhone through macOS's CoreDevice connection and prints
/// frames for `ascii-screen --frames`: "W H\n", then W*H*4 bytes of BGRA.
/// Status goes to stderr. Recording never wakes or unlocks the phone.
final class Capture {
  private let device: String
  private let interval: Double
  private var phone: Phone?
  private var controller: FrameReceiver?
  private var sharedAt: Double = 0
  private var lastState = ""

  init(device: String, interval: Double) {
    self.device = device
    self.interval = interval
  }

  /// Unknown state is treated as idle.
  static func canCapture(power: [String: Any]) -> Bool {
    power["Locked"] as? Bool == false && power["ScreenOn"] as? Bool == true
  }

  static func pollDelay(interval: Double, elapsed: Double, failures: Int) -> Double {
    if failures > 0 {
      // A timed-out request already spent its interval waiting. Back off
      // from completion instead of immediately opening another connection.
      return max(interval, min(30, 5 * pow(2, Double(min(failures - 1, 3)))))
    }
    // A capture slower than the interval means the link is slow: each frame
    // is a full PNG. Leave the link idle for three times as long as the
    // capture took, so phone control still gets through.
    return elapsed <= interval ? max(0.05, interval - elapsed) : min(15, 3 * elapsed)
  }

  /// "W H\n" followed by tightly packed BGRA rows.
  static func encode(_ image: CGImage) -> Data? {
    let width = image.width, height = image.height
    var pixels = Data(count: width * height * 4)
    let drawn = pixels.withUnsafeMutableBytes { bytes -> Bool in
      let space = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
      guard let context = CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8,
              bytesPerRow: width * 4, space: space,
              bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
      else { return false }
      context.interpolationQuality = .none
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    return drawn ? Data("\(width) \(height)\n".utf8) + pixels : nil
  }

  private func state(_ message: String) {
    guard message != lastState else { return }
    lastState = message
    FileHandle.standardError.write(Data("iPhone: \(message)\n".utf8))
  }

  private func connection() throws -> Phone {
    if let phone { return phone }
    let matches = try PhoneInfo.discover().filter { $0.id == device || $0.udid == device || $0.name == device }
    guard matches.count == 1 else {
      throw PhoneError("Expected one paired iPhone matching \(device), found \(matches.count)")
    }
    let connected = Phone(matches[0])
    phone = connected
    return connected
  }

  func run() -> Never {
    var failures = 0
    while true {
      let start = ProcessInfo.processInfo.systemUptime
      var delay = interval
      autoreleasepool {
        var phase = "device connection"
        do {
          let phone = try connection()
          phase = "state read"
          guard Self.canCapture(power: try phone.power()) else {
            failures = 0
            state("paused (locked, display off, or state unavailable)")
            delay = max(3, interval)
            return
          }
          // While the phone controller is streaming the display, use its
          // frames: a screenshot would compete with it for the link.
          if controller == nil { controller = try? FrameReceiver(udid: phone.info.udid) }
          let shared = controller?.latest(maxAge: 3)
          let now = ProcessInfo.processInfo.systemUptime
          if shared != nil { sharedAt = now }
          // The controller restarts its stream now and then. Wait out a
          // short gap rather than switch source and have the whole screen
          // re-read twice.
          if shared == nil, now - sharedAt < 8 { return }
          phase = "screenshot"
          guard let frame = Self.encode(try shared ?? phone.screenshot()) else {
            throw PhoneError("cannot convert the frame")
          }
          // ascii-screen closing the pipe is the signal to stop.
          do { try FileHandle.standardOutput.write(contentsOf: frame) } catch { exit(0) }
          failures = 0
          state(shared == nil ? "capturing through CoreDevice (\(device))"
                              : "capturing from the phone controller's video stream")
        } catch {
          phone = nil
          failures = min(failures + 1, 4)
          state("\(phase) unavailable: \(error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
      }
      Thread.sleep(forTimeInterval: Self.pollDelay(interval: delay,
        elapsed: ProcessInfo.processInfo.systemUptime - start, failures: failures))
    }
  }
}
