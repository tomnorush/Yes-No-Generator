import SwiftUI
import UIKit
import YesNoKit

/// A running log of answers: "what did I decide about this last time?"
struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var confirmingClear = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("History")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if !model.history.isEmpty {
                            Button("Clear All", role: .destructive) { confirmingClear = true }
                                .accessibilityIdentifier("history.clearAll")
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .confirmationDialog(
                    "Delete all saved answers?",
                    isPresented: $confirmingClear,
                    titleVisibility: .visible
                ) {
                    Button("Delete All", role: .destructive) { model.clearHistory() }
                } message: {
                    Text("This can't be undone.")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.history.isEmpty {
            ContentUnavailableView {
                Label(
                    model.historyEnabled ? LocalizedStringKey("No Answers Yet") : "History Is Off",
                    systemImage: "clock"
                )
            } description: {
                Text(model.historyEnabled
                     ? LocalizedStringKey("Answers you get will show up here. They stay on this device.")
                     : "Turn on Save History in Settings to keep a log of your answers.")
            }
        } else {
            List {
                ForEach(model.history.groupedByDay()) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            HistoryRow(entry: entry, theme: model.theme, colorScheme: colorScheme)
                        }
                        .onDelete { offsets in
                            model.deleteHistory(ids: Set(offsets.map { group.entries[$0].id }))
                        }
                    } header: {
                        Text(group.day, format: .dateTime.weekday(.wide).month().day())
                    }
                }

                Section {
                } footer: {
                    Text(footerText)
                }
            }
        }
    }

    private var footerText: LocalizedStringKey {
        if !model.historyEnabled {
            return "History is off, so new answers aren't being saved."
        }
        if model.isPro {
            return "Every answer is kept, only on this device. Swipe left on one to delete it."
        }
        return "Your last \(History.freeLimit) answers are kept, only on this device. Swipe left on one to delete it."
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry
    let theme: Theme
    let colorScheme: ColorScheme

    var body: some View {
        let palette = theme.palette(for: entry.answer, in: colorScheme)
        HStack(spacing: 12) {
            Text(entry.answer.word)
                .font(.system(.subheadline, design: .rounded).weight(.black))
                .foregroundStyle(palette.foreground)
                .frame(minWidth: 64)
                .padding(.vertical, 6)
                .background(palette.background, in: Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.question ?? String(localized: "No question"))
                    .foregroundStyle(entry.question == nil ? Color.secondary : Color.primary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(entry.date, format: .dateTime.hour().minute())
                    if let odds = entry.odds {
                        Text("· \(odds.summary(for: entry.mode))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.row.\(entry.id.uuidString)")
        .contextMenu {
            Button {
                UIPasteboard.general.string = ShareText.make(
                    answer: entry.answer, question: entry.question,
                    mode: entry.mode, odds: entry.odds ?? .fair
                )
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            ShareLink(item: ShareText.make(
                answer: entry.answer, question: entry.question,
                mode: entry.mode, odds: entry.odds ?? .fair
            ))
        }
    }
}
