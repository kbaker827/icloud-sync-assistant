import SwiftUI
import SyncCore

struct HelpSection: View {
    @Binding var showingIPhoneGuide: Bool
    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "More help", subtitle: "Shortcuts for when something still isn't showing up")
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                HelpButton(title: "Apple Account Settings", symbol: "person.crop.circle") {
                    SystemActions.openAppleAccountSettings()
                }
                HelpButton(title: "Open iCloud Drive", symbol: "folder") {
                    SystemActions.openICloudDrive()
                }
                HelpButton(title: "Apple System Status", symbol: "network") {
                    SystemActions.openSystemStatus()
                }
                HelpButton(title: "Sync from iPhone", symbol: "iphone") {
                    showingIPhoneGuide = true
                }
            }
        }
    }
}

private struct HelpButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

struct IPhoneGuideView: View {
    @Environment(\.dismiss) private var dismiss

    private let steps: [(symbol: String, text: String)] = [
        ("wifi", "Make sure the iPhone is on Wi-Fi and Low Power Mode is off (Settings > Battery)."),
        ("person.crop.circle", "Open Settings, tap your name at the top, then tap iCloud. Check that the apps you care about are turned on."),
        ("message", "For Messages: in that same iCloud screen, tap Messages in iCloud, then tap Sync Now."),
        ("photo", "For Photos: open Photos, tap Library and scroll to the bottom. If it says Paused, tap Resume."),
        ("folder", "For files: open the Files app, tap Browse > iCloud Drive and pull down to refresh."),
        ("bolt.fill", "Plug the iPhone in and leave it on Wi-Fi for a while. iPhones do most of their syncing while charging."),
        ("arrow.clockwise", "Still stuck? Restart the iPhone and press Sync Now on this Mac again."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Sync from the iPhone")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            Text("Syncing needs both devices to check in. Do these on the iPhone:")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.callout.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Palette.skyBottom))
                        Label(step.text, systemImage: step.symbol)
                            .labelStyle(TipLabelStyle())
                    }
                }
            }
        }
        .padding(26)
        .frame(width: 520)
    }
}

private struct TipLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 8) {
            configuration.icon
                .foregroundStyle(.secondary)
                .frame(width: 20)
            configuration.title
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
