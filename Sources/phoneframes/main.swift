import Foundation

let usage = "usage: phoneframes <device name or UUID> [--interval seconds]\n"
var arguments = Array(CommandLine.arguments.dropFirst())
var interval = 1.0
if let flag = arguments.firstIndex(of: "--interval") {
  guard flag + 1 < arguments.count, let value = Double(arguments[flag + 1]), value > 0 else {
    FileHandle.standardError.write(Data(usage.utf8)); exit(2)
  }
  interval = value
  arguments.removeSubrange(flag...(flag + 1))
}
guard arguments.count == 1, !arguments[0].hasPrefix("-") else {
  FileHandle.standardError.write(Data(usage.utf8)); exit(2)
}
signal(SIGPIPE, SIG_IGN)
let capture = Capture(device: arguments[0], interval: interval)
DispatchQueue.global(qos: .utility).async { capture.run() }
// CoreDevice delivers discovery and connection callbacks on the main loop.
RunLoop.main.run()
