import AppKit
import SwiftUI
import SyncCore

/// Renders the whole dashboard to a PNG for the README, using demo data.
/// Only active when ICSA_SCREENSHOT is set, e.g.
/// `open -n --env ICSA_SCREENSHOT=/tmp/out.png --env ICSA_SCENARIO=attention "iCloud Sync Assistant.app"`
/// Optional: ICSA_APPEARANCE=dark, ICSA_HEIGHT=<crop height in points>.
struct ScreenshotMode: Sendable {
    let outputURL: URL
    let scenario: DemoScenario
    let isDark: Bool
    let width: CGFloat
    let maxHeight: CGFloat?

    static let current: ScreenshotMode? = {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["ICSA_SCREENSHOT"], !path.isEmpty else { return nil }
        return ScreenshotMode(
            outputURL: URL(fileURLWithPath: path),
            scenario: environment["ICSA_SCENARIO"].flatMap(DemoScenario.init(rawValue:)) ?? .allGood,
            isDark: environment["ICSA_APPEARANCE"] == "dark",
            width: 960,
            maxHeight: environment["ICSA_HEIGHT"].flatMap(Double.init).map { CGFloat($0) }
        )
    }()

    var dependencies: SyncDependencies { .demo(scenario) }

    @MainActor
    func applyAppearance() {
        NSApp.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    }

    /// Hosts the full dashboard in a window that may be taller than the screen, then saves it.
    @MainActor
    func capture(model: SyncAssistantModel) async {
        let root = DashboardView(showingIPhoneGuide: .constant(false))
            .environmentObject(model)
            .frame(width: width)
            .background(Palette.page)
        let hosting = NSHostingView(rootView: root)
        let contentHeight = hosting.fittingSize.height
        log("capturing at \(Int(width))x\(Int(contentHeight))")

        let window = ScreenshotWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: contentHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "iCloud Sync Assistant"
        window.contentView = hosting
        window.setFrameOrigin(.zero)
        window.orderFrontRegardless()
        NSApp.windows.filter { $0 !== window }.forEach { $0.orderOut(nil) }

        // Let SwiftUI lay out and finish its animations.
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        let frameView = hosting.superview ?? hosting
        guard let bitmap = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds) else {
            fail("could not create bitmap")
            return
        }
        frameView.cacheDisplay(in: frameView.bounds, to: bitmap)

        guard let png = cropped(bitmap, scale: window.backingScaleFactor)?
            .representation(using: .png, properties: [:]) else {
            fail("could not encode PNG")
            return
        }
        do {
            try png.write(to: outputURL)
            log("saved \(outputURL.path)")
            exit(0)
        } catch {
            fail("could not write \(outputURL.path): \(error)")
        }
    }

    /// Keeps the top `maxHeight` points (title bar included) when a crop was requested.
    private func cropped(_ bitmap: NSBitmapImageRep, scale: CGFloat) -> NSBitmapImageRep? {
        guard let maxHeight, let image = bitmap.cgImage else { return bitmap }
        let height = min(CGFloat(image.height), (maxHeight * scale).rounded())
        guard let top = image.cropping(to: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: height)) else {
            return bitmap
        }
        return NSBitmapImageRep(cgImage: top)
    }

    func log(_ message: String) {
        FileHandle.standardError.write(Data("[screenshot] \(message)\n".utf8))
    }

    private func fail(_ message: String) {
        FileHandle.standardError.write(Data("Screenshot failed: \(message)\n".utf8))
        exit(1)
    }
}

/// A window that macOS won't shrink to fit the screen, so the whole dashboard is captured.
private final class ScreenshotWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
