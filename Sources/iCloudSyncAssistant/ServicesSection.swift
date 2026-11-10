import SwiftUI
import SyncCore

struct ServicesSection: View {
    @EnvironmentObject private var model: SyncAssistantModel
    private let columns = [GridItem(.adaptive(minimum: 190), spacing: 14, alignment: .top)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: "Your iCloud apps",
                subtitle: "Opening an app makes it catch up. Click ? for tips on the Mac and iPhone."
            )
            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                ForEach(ICloudService.allCases) { service in
                    ServiceCardView(service: service, state: model.serviceState(service))
                }
            }
        }
    }
}

struct ServiceCardView: View {
    let service: ICloudService
    let state: ServiceState
    @State private var showingTips = false
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image(systemName: service.symbolName)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(service.tint.gradient)
                    )
                    .accessibilityHidden(true)
                Spacer()
                ServiceStatePill(state: state)
            }
            Text(service.displayName)
                .font(.headline)
            HStack {
                Button("Open") {
                    SystemActions.open(service)
                }
                .controlSize(.large)
                .accessibilityLabel("Open \(service.displayName)")
                Spacer()
                Button {
                    showingTips.toggle()
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .help("How to make \(service.displayName) sync")
                .accessibilityLabel("Sync tips for \(service.displayName)")
                .popover(isPresented: $showingTips, arrowEdge: .bottom) {
                    ServiceTipsView(service: service)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
        .scaleEffect(isHovering ? 1.015 : 1)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

struct ServiceStatePill: View {
    let state: ServiceState

    private var text: String {
        switch state {
        case .on: return "On"
        case .off: return "Off"
        case .unknown: return "Not sure"
        }
    }

    private var color: Color {
        switch state {
        case .on: return .green
        case .off: return .orange
        case .unknown: return .secondary
        }
    }

    private var helpText: String {
        switch state {
        case .on: return "Turned on for this Mac"
        case .off: return "Turned off for this Mac. Turn it on in Apple Account Settings > iCloud."
        case .unknown: return "macOS didn't say whether this is on. Check Apple Account Settings > iCloud."
        }
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(Capsule().fill(color.opacity(0.14)))
            .help(helpText)
            .accessibilityLabel("Status: \(text)")
    }
}

struct ServiceTipsView: View {
    let service: ICloudService

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Make \(service.displayName) sync")
                .font(.headline)
            TipRow(symbol: "laptopcomputer", title: "On this Mac", text: service.macTip)
            TipRow(symbol: "iphone", title: "On the iPhone", text: service.iPhoneTip)
        }
        .padding(18)
        .frame(width: 340)
    }
}

private struct TipRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Palette.skyBottom)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
