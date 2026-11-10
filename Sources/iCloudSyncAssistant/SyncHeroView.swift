import SwiftUI
import SyncCore

/// The top banner: overall status, a plain-language headline and the big Sync Now button.
struct SyncHeroView: View {
    @EnvironmentObject private var model: SyncAssistantModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 24) {
                StatusBadge(status: model.report?.overall, isBusy: model.isBusy)
                headline
                Spacer(minLength: 16)
                SyncButton()
            }
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 20) {
                    StatusBadge(status: model.report?.overall, isBusy: model.isBusy)
                    headline
                }
                SyncButton()
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Palette.skyTop.opacity(0.18), Palette.skyBottom.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Palette.skyTop.opacity(0.25))
        )
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("iCloud Sync")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(model.statusMessage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: 0.2), value: model.statusMessage)
            if let lastSync = model.lastSyncDate {
                Text("Last synced at \(lastSync.formatted(date: .omitted, time: .shortened))")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct StatusBadge: View {
    let status: CheckStatus?
    let isBusy: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill((status?.color ?? Palette.skyTop).opacity(0.15))
            if isBusy || status == nil {
                ProgressView()
                    .controlSize(.large)
            } else if let status {
                Image(systemName: status.symbolName)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(status.color)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 84, height: 84)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: status)
        .animation(.easeInOut(duration: 0.2), value: isBusy)
        .accessibilityElement()
        .accessibilityLabel(isBusy ? "Working" : (status?.accessibilityLabel ?? "Checking"))
    }
}

struct SyncButton: View {
    @EnvironmentObject private var model: SyncAssistantModel

    var body: some View {
        Button {
            Task { await model.syncNow() }
        } label: {
            HStack(spacing: 10) {
                if model.isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .environment(\.colorScheme, .dark)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                Text(model.isBusy ? "Syncing…" : "Sync Now")
            }
            .font(.title2.weight(.semibold))
            .padding(.horizontal, 30)
            .padding(.vertical, 16)
            .frame(minWidth: 210)
        }
        .buttonStyle(SyncButtonStyle())
        .disabled(model.isBusy)
        .keyboardShortcut(.defaultAction)
        .accessibilityHint("Restarts iCloud's background sync and checks for problems")
    }
}

struct SyncButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [Palette.skyTop, Palette.skyBottom], startPoint: .top, endPoint: .bottom))
            )
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.25)))
            .shadow(
                color: Palette.skyBottom.opacity(configuration.isPressed ? 0.15 : 0.35),
                radius: configuration.isPressed ? 4 : 12,
                y: configuration.isPressed ? 2 : 6
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.7)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}
