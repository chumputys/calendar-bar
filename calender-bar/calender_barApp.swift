//
//  calender_barApp.swift
//  calender-bar
//
//  Created by Ubaidulla Ali on 23-5-26.
//

import SwiftUI
import Combine

@main
struct calender_barApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No main window: empty Settings scene keeps the app windowless on launch.
        Settings {
            EmptyView()
        }
    }
}

// MARK: - Settings

enum MenuBarDisplay: String, CaseIterable, Identifiable {
    case iconOnly, dateOnly, dateTime
    var id: String { rawValue }
    var label: String {
        switch self {
        case .iconOnly: "Icon Only"
        case .dateOnly: "Date Only"
        case .dateTime: "Date & Time"
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let key = "menuBarDisplay"

    @Published var displayMode: MenuBarDisplay {
        didSet { UserDefaults.standard.set(displayMode.rawValue, forKey: key) }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: key)
        displayMode = MenuBarDisplay(rawValue: raw ?? "") ?? .dateTime
    }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var timer: Timer?
    private var cancellable: AnyCancellable?
    private var clickMonitor: Any?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm" // always 24h, no seconds
        return f
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)

        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: PopoverView())

        updateStatusItem(mode: AppSettings.shared.displayMode)
        scheduleMinuteTimer()
        // $displayMode publishes in willSet (old value still stored), so use the emitted value.
        cancellable = AppSettings.shared.$displayMode.sink { [weak self] mode in
            self?.updateStatusItem(mode: mode)
        }
    }

    /// Fires exactly on the next minute boundary, then every 60s. `.common` mode keeps
    /// it ticking while the menu/popover is being tracked.
    private func scheduleMinuteTimer() {
        let nextMinute = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(second: 0),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(60)

        let t = Timer(fire: nextMinute, interval: 60, repeats: true) { [weak self] _ in
            self?.updateStatusItem(mode: AppSettings.shared.displayMode)
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func updateStatusItem(mode: MenuBarDisplay) {
        guard let button = statusItem.button else { return }
        let now = Date()
        switch mode {
        case .iconOnly:
            let image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")
            image?.isTemplate = true
            button.image = image
            button.title = ""
        case .dateOnly:
            button.image = nil
            button.title = dateFormatter.string(from: now)
        case .dateTime:
            button.image = nil
            button.title = "\(dateFormatter.string(from: now))  \(timeFormatter.string(from: now))"
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Close on any click outside the app (other apps, desktop, menu bar).
            clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.closePopover()
            }
        }
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    // Called for every close path (transient, outside click, toggle) — clean up the monitor.
    func popoverDidClose(_ notification: Notification) {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }
}
