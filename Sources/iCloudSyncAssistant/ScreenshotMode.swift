import AppKit
import SyncCore

/// Renders the app's own window to a PNG for the README, using demo data.
/// Only active when ICSA_SCREENSHOT is set, e.g.
/// `ICSA_SCREENSHOT=out.png ICSA_SCENARIO=attention ICSA_APPEARANCE=dark iCloudSyncAssistant`
struct ScreenshotMode: Sendable {
    let outputURL: URL
    let scenario: DemoScenario
    let isDark: Bool
    let contentSize: CGSize

    static let current: ScreenshotMode? = {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["ICSA_SCREENSHOT"], !path.isEmpty else { return nil }
        let height = environment["ICSA_HEIGHT"].flatMap(Double.init) ?? 1_480
        return ScreenshotMode(
            outputURL: URL(fileURLWithPath: path),
            scenario: environment["ICSA_SCENARIO"].flatMap(DemoScenario.init(rawValue:)) ?? .allGood,
            isDark: environment["ICSA_APPEARANCE"] == "dark",
            contentSize: CGSize(width: 960, height: height)
        )
    }()

    var dependencies: SyncDependencies { .demo(scenario) }

    @MainActor
    func applyAppearance() {
        NSApp.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    }

    @MainActor
    func capture() async {
        log("capturing \(NSApp.windows.count) window(s)")
        guard let window = NSApp.windows.first(where: { $0.contentView != nil }) else {
            fail("no window to capture")
            return
        }
        window.setContentSize(contentSize)
        window.center()
        // Let SwiftUI lay out and finish its animations.
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        guard let view = window.contentView?.superview ?? window.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            fail("could not create bitmap")
            return
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            fail("could not encode PNG")
            return
        }
        do {
            try png.write(to: outputURL)
            print("Saved screenshot to \(outputURL.path)")
            exit(0)
        } catch {
            fail("could not write \(outputURL.path): \(error)")
        }
    }

    func log(_ message: String) {
        FileHandle.standardError.write(Data("[screenshot] \(message)\n".utf8))
    }

    private func fail(_ message: String) {
        FileHandle.standardError.write(Data("Screenshot failed: \(message)\n".utf8))
        exit(1)
    }
}
