import SwiftUI
import SyncCore

struct ContentView: View {
    @EnvironmentObject private var model: SyncAssistantModel
    @State private var showingIPhoneGuide = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                SyncHeroView()
                HealthSection()
                ServicesSection()
                HelpSection(showingIPhoneGuide: $showingIPhoneGuide)
                FooterNote()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.page)
        .sheet(isPresented: $showingIPhoneGuide) {
            IPhoneGuideView()
        }
        .task {
            if let screenshot = ScreenshotMode.current {
                await model.syncNow()
                await screenshot.capture()
            } else {
                await model.runChecks()
            }
        }
    }
}

private struct FooterNote: View {
    var body: some View {
        Text("Apple doesn't offer a button that forces every iCloud app to sync instantly. Sync Now does the next best thing: it restarts iCloud's background sync on this Mac so it checks in with Apple right away, then checks for anything that would hold syncing up. It never deletes files, changes settings, or asks for your password.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
