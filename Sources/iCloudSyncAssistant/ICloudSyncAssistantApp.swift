import AppKit
import SwiftUI
import SyncCore

@main
struct ICloudSyncAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = SyncAssistantModel(dependencies: ScreenshotMode.current?.dependencies ?? .live)

    var body: some Scene {
        WindowGroup("iCloud Sync Assistant") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 720, minHeight: 600)
        }
        .defaultSize(width: 940, height: 820)
        .commands {
            // A single-window app: no File > New Window.
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Sync Now") {
                    Task { await model.syncNow() }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(model.isBusy)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        ScreenshotMode.current?.applyAppearance()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
