# CapsLockLED 💡

**Turn your MacBook's Caps Lock light into a status light for Claude Code.**

While Claude works, the Caps Lock key's light blinks. When Claude needs you or
finishes, it signals differently — so you can look away from the screen and
still know what's happening at a glance.

| The Caps Lock light does this… | …when |
| --- | --- |
| 🔵 **Slow blink** | Claude is working on your request |
| 🟠 **Fast blink** | Claude is waiting for you (a permission prompt, a question, or it's idle) |
| 🟢 **Two quick flashes, then off** | Claude finished responding |

> Your actual Caps Lock stays off the whole time — only the *light* is used.
> The app never reads what you type.

---

## Install (the easy way) — about 2 minutes

1. **Open `CapsLockLED.dmg`** (double-click it).

2. In the window that opens, **drag the CapsLockLED icon onto the Applications
   folder** next to it.

   ![drag to Applications]  ← that's the whole install.

3. Open your **Applications** folder, then **right-click CapsLockLED and choose
   "Open"**.
   - Do this the *first time only*. Because this app isn't from the Mac App
     Store, a plain double-click may show a warning — **right-click → Open**
     gets past it. Click **Open** on the dialog that appears.

4. Look at the **top-right of your screen** (the menu bar). You'll see a small
   circle icon — that's CapsLockLED running.
   - **Don't see it?** If you use a menu-bar organizer like **Barbee**,
     Bartender, or Ice, it may be hiding the icon. Click its expand arrow and
     drag CapsLockLED into the visible area.

5. **Grant permission.** The first time it runs, click the icon →
   **"Open Input Monitoring Settings…"**, turn **CapsLockLED** on in the list,
   then **quit and reopen** the app.
   - This "Input Monitoring" permission is simply what macOS requires to touch
     the keyboard light. The app doesn't log or send anything.

6. **Connect it to Claude Code.** Click the menu bar icon →
   **"Set Up Claude Code Hooks"**. That's it — you'll get a confirmation.

7. **Start a new Claude Code session** and watch the Caps Lock light react. 🎉

**Recommended:** click the icon → **"Launch at Login"** so it's always ready.

---

## Using it day to day

- Just keep the app running (Launch at Login handles this). Every Claude Code
  session on this Mac will drive the light automatically.
- The menu bar icon changes color too (blue / orange / green), so it mirrors
  the light.
- **Test it anytime:** menu bar icon → **Test Blink** → Working / Needs Input /
  Done.

---

## Troubleshooting

**The menu bar icon isn't there.**
A menu-bar manager (Barbee, Bartender, Ice, Hidden Bar…) is probably hiding it.
Reveal hidden icons and drag CapsLockLED into the always-shown area. The app is
still running — this is just about showing its icon.

**The light doesn't respond.**
- Make sure the app is running (icon in the menu bar).
- Check **System Settings → Privacy & Security → Input Monitoring** and confirm
  **CapsLockLED** is turned on. If it's on but still not working, toggle it off
  and on, then quit and reopen the app.
- Use **Test Blink** in the menu to check the light directly. If Test Blink
  works but Claude Code doesn't trigger it, re-run **"Set Up Claude Code
  Hooks"** and start a *new* Claude Code session (hooks load when a session
  starts).

**macOS says the app "can't be opened" or is "damaged".**
Right-click the app → **Open** (instead of double-clicking). If it still
refuses, run this once in Terminal:
`xattr -dr com.apple.quarantine /Applications/CapsLockLED.app`

**I want to disconnect it from Claude Code.**
Menu bar icon → **"Remove Claude Code Hooks"**.

---

## Sharing this with someone else

This app is **self-signed**, not notarized by Apple. On **your** Mac it opens
normally. If you send the `.dmg` to a friend, their Mac's Gatekeeper will be
more suspicious — they'd need the right-click → Open / `xattr` step above, and
even then macOS may warn about an unidentified developer. To distribute it
widely and cleanly you'd need an Apple Developer account to sign & notarize it.

---

## For developers

Built as a Swift Package (no Xcode project needed — just Command Line Tools).

```sh
./build.sh      # compiles and assembles CapsLockLED.app (code-signed locally)
./make-dmg.sh   # packages CapsLockLED.app into dist/CapsLockLED.dmg
```

**How it fits together**
- `CapsLockLED.app` — a menu bar app (`LSUIElement`). Talks to the keyboard's
  HID LED element via IOKit (`IOHIDDeviceSetValue`) to toggle the Caps Lock
  light without changing the Caps Lock state.
- `caps-signal` — a tiny CLI inside the bundle
  (`Contents/MacOS/caps-signal`). Claude Code hooks call it; it posts a
  `DistributedNotificationCenter` message that the running app reacts to. It
  needs no permissions of its own.
- The `Notification` hook is scoped with a **matcher** so Claude Code only runs
  it for notification types that mean Claude is genuinely blocked on you
  (`permission_prompt`, `idle_prompt`, `agent_needs_input`,
  `elicitation_dialog`) — it fires `caps-signal needs-input` directly, so
  there's no stdin JSON parsing.
- `HookInstaller.swift` — the "Set Up Claude Code Hooks" logic. Also runnable
  headless: `CapsLockLED --setup-hooks` / `--remove-hooks`. It merges three
  hooks into `~/.claude/settings.json`, pointing at the app's own bundle, and
  preserves any other settings/hooks you already have.

**Hooks installed**
- `UserPromptSubmit` → `caps-signal working`
- `Stop` → `caps-signal done`
- `Notification` (matcher `permission_prompt|idle_prompt|agent_needs_input|elicitation_dialog`) → `caps-signal needs-input`

**Code signing note.** `build.sh` signs with a local self-signed identity
("CapsLockLED Dev") if present, otherwise falls back to ad-hoc. A *stable*
identity matters because macOS ties the Input Monitoring grant to the app's
signature — with ad-hoc signing, every rebuild changes the signature and resets
the permission. To create the identity once:

```sh
# generate a self-signed code-signing cert named "CapsLockLED Dev",
# import it into your login keychain, and trust it for code signing
# (see the commit history / your notes for the exact security+openssl commands)
```

**Permission gotcha.** macOS attributes Input Monitoring to the *responsible*
process that launched the app. If you launch it from a terminal or another
tool, macOS may check *that* app's permission instead. Launch CapsLockLED from
Finder so it's judged on its own.
