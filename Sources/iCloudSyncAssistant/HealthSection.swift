import SwiftUI
import SyncCore

struct HealthSection: View {
    @EnvironmentObject private var model: SyncAssistantModel
    private let columns = [GridItem(.adaptive(minimum: 300), spacing: 14, alignment: .top)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Health check", subtitle: "Things on this Mac that can hold iCloud up")
            if let report = model.report {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(report.results) { result in
                        CheckRowView(result: result)
                    }
                }
                if let restart = model.lastRestart {
                    Label(restart.summary, systemImage: restart.succeeded ? "bolt.horizontal.circle" : "exclamationmark.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Running checks…").foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
    }
}

struct CheckRowView: View {
    let result: CheckResult

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: result.status.symbolName)
                .font(.title2)
                .foregroundStyle(result.status.color)
                .frame(width: 28)
                .accessibilityLabel(result.status.accessibilityLabel)
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                Text(result.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
        .accessibilityElement(children: .combine)
    }
}
