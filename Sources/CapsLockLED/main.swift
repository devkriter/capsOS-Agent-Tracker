import Cocoa

// Headless entry points so the hook wiring can be tested/scripted without the GUI.
if CommandLine.arguments.contains("--setup-hooks") || CommandLine.arguments.contains("--remove-hooks") {
    let remove = CommandLine.arguments.contains("--remove-hooks")
    do {
        let message = try HookInstaller.run(remove: remove)
        print(message)
        exit(0)
    } catch {
        FileHandle.standardError.write((error.localizedDescription + "\n").data(using: .utf8)!)
        exit(1)
    }
}

let appDelegate = AppDelegate()
let application = NSApplication.shared
application.delegate = appDelegate
application.setActivationPolicy(.accessory)
application.run()
