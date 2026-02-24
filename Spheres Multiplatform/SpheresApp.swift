//
//  SpheresApp.swift
//  Spheres Multiplatform
//
//  Created by Naomi Ivie on 10/20/25.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct SpheresApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SphereModel.self,
            OpenLoopModel.self,
            InboxItemModel.self
        ])

        // Check if iCloud is enabled
        let iCloudEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")

        if iCloudEnabled {
            // Use CloudKit configuration
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.naomiivie.SpheresMultiplatform")
            )

            do {
                let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                print("DEBUG: CloudKit ModelContainer created successfully")
                return container
            } catch {
                print("DEBUG: Failed to create CloudKit ModelContainer: \(error), falling back to local")
                // Disable iCloud sync if it fails
                UserDefaults.standard.set(false, forKey: "iCloudSyncEnabled")
            }
        }

        // Use default local storage (SwiftData handles location automatically)
        do {
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("DEBUG: Local ModelContainer created successfully")
            return container
        } catch {
            print("DEBUG: Failed to create local ModelContainer: \(error)")

            // Last resort: try deleting corrupted data and recreate
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let defaultStoreURL = appSupportURL.appendingPathComponent("default.store")
            try? FileManager.default.removeItem(at: defaultStoreURL)

            do {
                let container = try ModelContainer(for: schema)
                print("DEBUG: Fresh ModelContainer created after cleanup")
                return container
            } catch {
                print("DEBUG: All attempts failed: \(error)")
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 500)
                .onAppear {
                    // Disable window transparency
                    if let window = NSApplication.shared.windows.first {
                        window.isOpaque = true
                        window.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1.0)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Quick Capture") {
                    NotificationCenter.default.post(name: .showQuickCapture, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }

        // Menu bar extra for quick capture
        MenuBarExtra("Spheres", systemImage: "circle.grid.2x2.fill") {
            Button("Open Spheres") {
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("o")

            Button("Quick Capture") {
                NSApp.activate(ignoringOtherApps: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: .showQuickCapture, object: nil)
                }
            }
            .keyboardShortcut("n")

            Divider()

            Button("Quit Spheres") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permissions
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                print("Notification permission granted")
            }
        }
    }

    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let showQuickCapture = Notification.Name("showQuickCapture")
    static let showProactivePopup = Notification.Name("showProactivePopup")
}

// MARK: - Notification Helpers
struct NotificationHelper {
    static func scheduleDueReminder(for loop: OpenLoopModel) {
        guard let dueDate = loop.dueDate else { return }

        let content = UNMutableNotificationContent()
        content.title = "Loop Due Soon"
        content.body = loop.content
        content.sound = .default

        // Remind 1 hour before
        let reminderDate = Calendar.current.date(byAdding: .hour, value: -1, to: dueDate) ?? dueDate
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: loop.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func scheduleHabitReminder(for loop: OpenLoopModel, at hour: Int = 9) {
        guard loop.isHabit else { return }

        let content = UNMutableNotificationContent()
        content.title = "Daily Habit"
        content.body = "\(loop.content) — Keep your \(loop.currentStreak) day streak going!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "habit-\(loop.id.uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelNotification(for loopId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [loopId.uuidString, "habit-\(loopId.uuidString)"])
    }
}

