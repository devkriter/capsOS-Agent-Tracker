import Foundation

/// Writes the three Claude Code hooks into ~/.claude/settings.json, pointing
/// them at this app bundle's own caps-signal helper. Safe to run repeatedly:
/// it merges into any existing settings and only touches the three hook events
/// it owns, preserving everything else (theme, other hooks).
enum HookInstaller {
    struct InstallError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Removing the hooks is just installing with `remove: true`.
    static func run(remove: Bool = false) throws -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let claudeDir = home.appendingPathComponent(".claude", isDirectory: true)
        let settingsURL = claudeDir.appendingPathComponent("settings.json")

        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        // Load existing settings (or start fresh). Refuse to clobber a file we
        // can't parse — the user may have hand-edited it.
        var settings: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: settingsURL.path) {
            let data = try Data(contentsOf: settingsURL)
            if !data.isEmpty {
                guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw InstallError(message: "~/.claude/settings.json isn't a JSON object — not touching it. Please fix it by hand.")
                }
                settings = parsed
                // Back up before modifying.
                let backup = settingsURL.appendingPathExtension("capslockled-backup")
                try? data.write(to: backup)
            }
        }

        var hooks = (settings["hooks"] as? [String: Any]) ?? [:]

        if remove {
            for key in ["UserPromptSubmit", "Stop", "Notification"] {
                if let entries = hooks[key] as? [[String: Any]] {
                    let filtered = entries.filter { !entryBelongsToUs($0) }
                    if filtered.isEmpty { hooks.removeValue(forKey: key) }
                    else { hooks[key] = filtered }
                }
            }
            settings["hooks"] = hooks.isEmpty ? nil : hooks
            try write(settings, to: settingsURL)
            return "Removed CapsLockLED hooks from ~/.claude/settings.json.\n\nRestart any open Claude Code sessions for this to take effect."
        }

        let bundlePath = Bundle.main.bundlePath
        if bundlePath.contains(" ") {
            throw InstallError(message: "CapsLockLED is installed in a folder whose path contains spaces:\n\n\(bundlePath)\n\nMove it to /Applications (drag it there) and try again — hook commands can't handle spaces in the path.")
        }
        let capsSignal = bundlePath + "/Contents/MacOS/caps-signal"

        hooks["UserPromptSubmit"] = mergeOurEntry(
            into: hooks["UserPromptSubmit"],
            command: capsSignal + " working"
        )
        hooks["Stop"] = mergeOurEntry(
            into: hooks["Stop"],
            command: capsSignal + " done"
        )
        // Claude Code filters Notification hooks by matcher (the notification
        // type). We fire "needs input" only for prompts that wait on you; the
        // app caps how long that fast-blink lasts, so a background session
        // going idle can't latch the light on. (agent_needs_input is left out —
        // it's noisy across many concurrent sessions.)
        hooks["Notification"] = mergeOurEntry(
            into: hooks["Notification"],
            command: capsSignal + " needs-input",
            matcher: "permission_prompt|idle_prompt|elicitation_dialog"
        )
        settings["hooks"] = hooks

        try write(settings, to: settingsURL)
        return "Claude Code hooks installed in ~/.claude/settings.json.\n\n• Working  → LED slow-blinks\n• Waiting on you → LED fast-blinks\n• Done → LED double-flashes\n\nStart a NEW Claude Code session for the hooks to take effect. Keep CapsLockLED running (turn on \"Launch at Login\") so it can drive the LED."
    }

    // We recognise our own entries by the command they run, using only standard
    // hook keys (matcher/hooks/type/command) so nothing can trip hook-schema
    // validation. The `capslock-notify.sh` clause matches entries written by
    // older versions so a re-run cleanly upgrades them.
    private static func entryBelongsToUs(_ entry: [String: Any]) -> Bool {
        guard let inner = entry["hooks"] as? [[String: Any]] else { return false }
        return inner.contains { hook in
            guard let command = hook["command"] as? String else { return false }
            return command.contains("CapsLockLED.app")
                && (command.contains("caps-signal") || command.contains("capslock-notify.sh"))
        }
    }

    /// Replaces our previous entry for this event (if any) and appends the new
    /// one, leaving any unrelated entries the user has for the same event. When
    /// `matcher` is set it's written so Claude Code only runs the hook for those
    /// notification types.
    private static func mergeOurEntry(into existing: Any?, command: String, matcher: String? = nil) -> [[String: Any]] {
        var entries = (existing as? [[String: Any]]) ?? []
        entries.removeAll(where: entryBelongsToUs)
        var entry: [String: Any] = ["hooks": [["type": "command", "command": command]]]
        if let matcher = matcher {
            entry["matcher"] = matcher
        }
        entries.append(entry)
        return entries
    }

    private static func write(_ settings: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: url)
    }
}
