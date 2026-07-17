import Foundation
import IOKit
import IOKit.hid

enum HIDAccessStatus {
    case granted
    case denied
    case unknown
}

/// Talks directly to the keyboard's HID LED element so the Caps Lock light
/// can be toggled without touching the actual Caps Lock modifier state.
final class LEDController {
    private var manager: IOHIDManager?
    private var capsLockElements: [(device: IOHIDDevice, element: IOHIDElement)] = []

    init() {
        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keyboard
        ]
        IOHIDManagerSetDeviceMatching(mgr, matching as CFDictionary)
        IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = mgr
        refreshCapsLockElements()
    }

    private func refreshCapsLockElements() {
        capsLockElements.removeAll()
        guard let mgr = manager,
              let deviceSet = IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice> else { return }

        let elementMatching: [String: Any] = [
            kIOHIDElementUsagePageKey as String: kHIDPage_LEDs,
            kIOHIDElementUsageKey as String: kHIDUsage_LED_CapsLock
        ]

        for device in deviceSet {
            guard let elements = IOHIDDeviceCopyMatchingElements(
                device, elementMatching as CFDictionary, IOOptionBits(kIOHIDOptionsTypeNone)
            ) as? [IOHIDElement] else { continue }

            for element in elements {
                capsLockElements.append((device, element))
            }
        }
    }

    /// Sets the caps lock LED on/off across every matching keyboard device.
    /// Returns true if at least one device accepted the write.
    @discardableResult
    func setLED(on: Bool) -> Bool {
        if capsLockElements.isEmpty {
            refreshCapsLockElements()
        }
        guard !capsLockElements.isEmpty else { return false }

        var success = false
        for (device, element) in capsLockElements {
            let value = IOHIDValueCreateWithIntegerValue(kCFAllocatorDefault, element, 0, on ? 1 : 0)
            if IOHIDDeviceSetValue(device, element, value) == kIOReturnSuccess {
                success = true
            }
        }
        return success
    }

    var hasCapsLockDevice: Bool {
        if capsLockElements.isEmpty {
            refreshCapsLockElements()
        }
        return !capsLockElements.isEmpty
    }

    static func checkAccess() -> HIDAccessStatus {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted:
            return .granted
        case kIOHIDAccessTypeDenied:
            return .denied
        default:
            return .unknown
        }
    }
}
