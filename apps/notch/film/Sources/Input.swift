import AppKit
import ObjectiveC

/// The pointer, driven with Quartz events so the app's hover gate, row hover and clicks run
/// as they would under a hand. Points are in AppKit screen coordinates (origin bottom-left).
@MainActor
enum Pointer {
    private static var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    static func jump(to point: CGPoint) {
        post(.mouseMoved, at: point)
    }

    /// Glides along a slight arc, easing in and out, one event every 1/120 s.
    static func move(to target: CGPoint, duration: TimeInterval, bend: CGFloat = 0.1) async {
        let start = NSEvent.mouseLocation
        let control = CGPoint(
            x: (start.x + target.x) / 2 - (target.y - start.y) * bend,
            y: (start.y + target.y) / 2 + (target.x - start.x) * bend
        )
        let steps = max(Int(duration * 120), 1)
        let clock = ContinuousClock()
        let began = clock.now
        for step in 1...steps {
            let t = Double(step) / Double(steps)
            let u = CGFloat(t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2)
            let point = CGPoint(
                x: (1 - u) * (1 - u) * start.x + 2 * (1 - u) * u * control.x + u * u * target.x,
                y: (1 - u) * (1 - u) * start.y + 2 * (1 - u) * u * control.y + u * u * target.y
            )
            post(.mouseMoved, at: point)
            try? await clock.sleep(until: began + .seconds(duration * t))
        }
    }

    static func click() async {
        let point = NSEvent.mouseLocation
        post(.leftMouseDown, at: point)
        try? await Task.sleep(for: .milliseconds(120))
        post(.leftMouseUp, at: point)
    }

    private static func post(_ type: CGEventType, at point: CGPoint) {
        let event = CGEvent(
            mouseEventSource: nil, mouseType: type,
            mouseCursorPosition: CGPoint(x: point.x, y: primaryHeight - point.y), mouseButton: .left
        )
        if type != .mouseMoved { event?.setIntegerValueField(.mouseEventClickState, value: 1) }
        event?.post(tap: .cghidEventTap)
    }
}

/// ⌥ held, inside this process only. The app reads `NSEvent.modifierFlags` to show details;
/// a real key event would also reach whichever app is in front.
@MainActor
enum Modifiers {
    nonisolated(unsafe) static var held: NSEvent.ModifierFlags = []

    static func install() {
        guard let original = class_getClassMethod(NSEvent.self, #selector(getter: NSEvent.modifierFlags)),
              let fake = class_getClassMethod(FakeModifiers.self, #selector(FakeModifiers.modifierFlags))
        else { return }
        method_setImplementation(original, method_getImplementation(fake))
    }
}

private final class FakeModifiers: NSObject {
    @objc class func modifierFlags() -> NSEvent.ModifierFlags { Modifiers.held }
}
