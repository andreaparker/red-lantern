import AppKit
import CoreGraphics
import Darwin

signal(SIGPIPE, SIG_IGN)
let arguments = CommandLine.arguments
if arguments.contains("--restore") {
    CGDisplayRestoreColorSyncSettings()
    print("System ColorSync settings restored.")
    exit(0)
}
if arguments.contains("--display-test") {
    exit(DisplayCheck.run())
}
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
