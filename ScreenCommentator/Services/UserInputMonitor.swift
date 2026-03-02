import Foundation
import CoreGraphics

final class UserInputMonitor: @unchecked Sendable {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let lock = NSLock()
    private var events: [(type: EventType, timestamp: Date, location: CGPoint?)] = []
    private let maxEvents = 100

    enum EventType {
        case click
        case rightClick
        case scroll
        case keyDown
    }

    var isAvailable: Bool {
        CGPreflightListenEventAccess()
    }

    func start() {
        guard eventTap == nil else { return }

        if !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
            print("[ScreenCommentator] Input Monitoring permission requested")
            return
        }

        let mask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.scrollWheel.rawValue)
            | (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<UserInputMonitor>.fromOpaque(refcon).takeUnretainedValue()

            let eventType: EventType?
            let location: CGPoint?

            switch type {
            case .leftMouseDown:
                eventType = .click
                location = event.location
            case .rightMouseDown:
                eventType = .rightClick
                location = event.location
            case .scrollWheel:
                eventType = .scroll
                location = nil
            case .keyDown:
                eventType = .keyDown
                location = nil
            default:
                eventType = nil
                location = nil
            }

            if let eventType {
                monitor.record(type: eventType, location: location)
            }

            return Unmanaged.passUnretained(event)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: selfPtr
        ) else {
            print("[ScreenCommentator] Failed to create event tap")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        print("[ScreenCommentator] Input monitoring started")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        lock.withLock { events.removeAll() }
    }

    func snapshot(windowSeconds: TimeInterval = 4.0) -> UserInputSnapshot {
        let cutoff = Date().addingTimeInterval(-windowSeconds)
        let typingCutoff = Date().addingTimeInterval(-2.0)

        let recentEvents = lock.withLock {
            events.filter { $0.timestamp > cutoff }
        }

        let clicks = recentEvents.filter { $0.type == .click || $0.type == .rightClick }.count
        let scrolls = recentEvents.filter { $0.type == .scroll }.count
        let isTyping = recentEvents.contains { $0.type == .keyDown && $0.timestamp > typingCutoff }
        let lastClick = recentEvents.last { $0.type == .click || $0.type == .rightClick }?.location

        return UserInputSnapshot(
            recentClicks: clicks,
            recentScrolls: scrolls,
            isTyping: isTyping,
            lastClickLocation: lastClick
        )
    }

    private func record(type: EventType, location: CGPoint?) {
        lock.withLock {
            events.append((type: type, timestamp: Date(), location: location))
            if events.count > maxEvents {
                events.removeFirst(events.count - maxEvents)
            }
        }
    }
}
