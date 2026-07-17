import Foundation

// Tiny CLI invoked from Claude Code hooks. Posts a distributed notification
// that the running CapsLockLED menu bar app observes and reacts to.

let validStates: Set<String> = ["working", "needs-input", "done", "idle"]
let notificationName = NSNotification.Name("com.furkansenturk.capslockled.signal")

let args = CommandLine.arguments
guard args.count == 2, validStates.contains(args[1]) else {
    FileHandle.standardError.write(
        "Usage: caps-signal <working|needs-input|done|idle>\n".data(using: .utf8)!
    )
    exit(1)
}

DistributedNotificationCenter.default().postNotificationName(
    notificationName,
    object: args[1],
    userInfo: nil,
    deliverImmediately: true
)
