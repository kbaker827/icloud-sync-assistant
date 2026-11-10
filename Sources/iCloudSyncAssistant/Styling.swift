import AppKit
import SwiftUI
import SyncCore

enum Palette {
    static let skyTop = Color(red: 0.24, green: 0.62, blue: 1.0)
    static let skyBottom = Color(red: 0.04, green: 0.37, blue: 0.90)
    static let card = Color(nsColor: .controlBackgroundColor)
    static let page = Color(nsColor: .windowBackgroundColor)
    static let hairline = Color.primary.opacity(0.08)
}

extension CheckStatus {
    var color: Color {
        switch self {
        case .good: return .green
        case .unknown: return .secondary
        case .warning: return .orange
        case .problem: return .red
        }
    }

    var symbolName: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .problem: return "xmark.octagon.fill"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .good: return "OK"
        case .unknown: return "Not sure"
        case .warning: return "Warning"
        case .problem: return "Problem"
        }
    }
}

extension ICloudService {
    var tint: Color {
        switch self {
        case .photos: return .orange
        case .messages: return .green
        case .notes: return .yellow
        case .contacts: return .brown
        case .calendar: return .red
        case .reminders: return .blue
        case .safari: return .teal
        case .passwords: return .indigo
        case .drive: return .cyan
        }
    }
}

struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Palette.card)
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Palette.hairline)
            )
    }
}

extension View {
    func cardBackground(cornerRadius: CGFloat = 16) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius))
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
