import Foundation

enum LEDState: String {
    case idle
    case working
    case needsInput = "needs-input"
    case done
}

/// Drives the physical LED patterns for each Claude Code status.
final class BlinkEngine {
    private let led: LEDController
    private var timer: DispatchSourceTimer?
    private var autoClear: DispatchWorkItem?
    private var isOn = false
    private(set) var state: LEDState = .idle

    // How long the fast "needs input" blink runs before clearing itself to off.
    // The hooks are global, so a background session going idle can fire
    // "needs-input"; without this cap the light would latch on until some
    // session happened to send another signal.
    private let needsInputTimeout: TimeInterval = 10

    var onStateChange: ((LEDState) -> Void)?

    init(led: LEDController) {
        self.led = led
    }

    func setState(_ newState: LEDState) {
        stopTimer()
        state = newState
        onStateChange?(newState)

        switch newState {
        case .idle:
            setLED(false)
        case .working:
            startBlinking(interval: 0.5)
        case .needsInput:
            startBlinking(interval: 0.1)
            scheduleAutoClear(after: needsInputTimeout)
        case .done:
            playDoneSequence()
        }
    }

    private func startBlinking(interval: TimeInterval) {
        isOn = true
        setLED(true)
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + interval, repeating: interval)
        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.isOn.toggle()
            self.setLED(self.isOn)
        }
        t.resume()
        timer = t
    }

    /// Caps the fast "needs input" blink: if nothing supersedes it within the
    /// timeout, fall back to idle so the light never sticks on. A fresh
    /// needs-input signal reschedules this (via stopTimer + setState).
    private func scheduleAutoClear(after seconds: TimeInterval) {
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.state == .needsInput else { return }
            self.setState(.idle)
        }
        autoClear = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    /// Two quick flashes, then back to idle. Runs on the main queue so
    /// a state change arriving mid-sequence cleanly interrupts it.
    private func playDoneSequence() {
        setLED(false)
        let schedule: [(delay: TimeInterval, on: Bool)] = [
            (0.00, true), (0.15, false), (0.30, true), (0.45, false)
        ]
        for (index, step) in schedule.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + step.delay) { [weak self] in
                guard let self = self, self.state == .done else { return }
                self.setLED(step.on)
                if index == schedule.count - 1 {
                    self.state = .idle
                    self.onStateChange?(.idle)
                }
            }
        }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
        autoClear?.cancel()
        autoClear = nil
    }

    private func setLED(_ on: Bool) {
        led.setLED(on: on)
    }
}
