import SwiftUI
import YesNoKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingClear = false

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $model.appearance) {
                        ForEach(Appearance.allCases, id: \.self) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("settings.appearance")
                }

                if model.showsProSettings {
                    ThemeSection()
                    OddsSection()
                }

                Section {
                    Toggle("Haptics", isOn: $model.hapticsEnabled)
                } footer: {
                    Text("A light tap you can feel with each new answer.")
                }

                Section {
                    Toggle("Save History", isOn: $model.historyEnabled)
                        .accessibilityIdentifier("settings.history")
                    Button("Clear History", role: .destructive) { confirmingClear = true }
                        .disabled(model.history.isEmpty)
                } header: {
                    Text("History")
                } footer: {
                    Text(model.isPro
                         ? LocalizedStringKey("History stays on this device and is never uploaded. Every answer is kept.")
                         : "History stays on this device and is never uploaded. Your last \(History.freeLimit) answers are kept.")
                }

                if ProStore.isOfflineBuild {
                    OfflineBuildSection()
                } else {
                    if model.isPro || model.mayMentionPro {
                        ProSection()
                    }
                    PurchasesSection()
                }

                AboutSection()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settings.done")
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
}

// MARK: - Themes (Pro)

private struct ThemeSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 12)]

    var body: some View {
        Section {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Theme.all) { theme in
                    swatch(for: theme)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Color Theme")
        } footer: {
            if !model.isPro {
                Text("Classic is free. The other themes come with Pro.")
            }
        }
    }

    private func swatch(for theme: Theme) -> some View {
        let locked = theme.isPro && !model.isPro
        let selected = model.theme.id == theme.id
        return Button {
            model.chosenThemeID = theme.id
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    ForEach([Answer.yes, .no, .maybe], id: \.self) { answer in
                        theme.palette(for: answer, in: colorScheme).background
                    }
                }
                .frame(height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.15),
                                      lineWidth: selected ? 3 : 1)
                }
                .overlay {
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(Color.black.opacity(0.55), in: Circle())
                    }
                }
                Text(theme.name)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityLabel(Text(theme.name))
        .accessibilityValue(locked ? Text("Needs Pro") : Text(""))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Odds (Pro)

private struct OddsSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let odds = model.chosenOdds
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Chance of Yes")
                    Spacer()
                    Text(odds.summary(for: .yesNo))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { model.chosenOdds.yesShare },
                        set: { model.chosenOdds = Odds(yesShare: $0) }
                    ),
                    in: Odds.allowedRange,
                    step: 0.05
                ) {
                    Text("Chance of Yes")
                } minimumValueLabel: {
                    Text("No").font(.caption)
                } maximumValueLabel: {
                    Text("Yes").font(.caption)
                }
                .accessibilityValue(Text(odds.summary(for: .yesNo)))
            }
            .disabled(!model.isPro)

            if !odds.isFair {
                Button("Reset to 50 / 50") { model.chosenOdds = .fair }
                    .disabled(!model.isPro)
            }
        } header: {
            Text("Odds")
        } footer: {
            Text(model.isPro
                 ? LocalizedStringKey("Lean the answer toward what you're already leaning toward. Whenever the odds aren't 50 / 50, the main screen and anything you share say so. Maybe always keeps a one-third chance.")
                 : "Custom odds come with Pro. Answers are always 50 / 50 without it.")
        }
    }
}

// MARK: - Pro

private struct ProSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let store = model.store
        Section {
            if store.isPro {
                Label("Pro is unlocked. Thank you!", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Yes or No is free and stays free: no ads, no subscription, no limits on answers. Pro is a single optional purchase that adds:")
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Six more color themes", systemImage: "paintpalette")
                        Label("Custom odds, from 10/90 to 90/10", systemImage: "slider.horizontal.3")
                        Label("Unlimited history", systemImage: "clock.arrow.circlepath")
                    }
                    .font(.subheadline)
                }
                .padding(.vertical, 4)

                switch store.productState {
                case .loaded:
                    if let product = store.product {
                        Button {
                            Task { await store.purchase() }
                        } label: {
                            HStack {
                                Text("Unlock Pro — \(product.displayPrice), once")
                                Spacer()
                                if store.isPurchasing {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(store.isPurchasing)
                        .accessibilityIdentifier("pro.buy")
                    }
                case .notLoaded, .loading:
                    HStack {
                        Text("Checking the App Store…")
                            .foregroundStyle(.secondary)
                        Spacer()
                        ProgressView()
                    }
                case .unavailable:
                    VStack(alignment: .leading, spacing: 6) {
                        Text("The App Store can't be reached right now. Everything else in the app works offline.")
                            .foregroundStyle(.secondary)
                        Button("Try Again") {
                            Task { await store.loadProductIfNeeded() }
                        }
                    }
                }
            }
        } header: {
            Text("Yes or No Pro")
        } footer: {
            if !store.isPro {
                Text("One-time purchase. No subscription.")
            }
        }
        .task { await store.loadProductIfNeeded() }
    }
}

/// Always visible, so a purchase is never lost, even before Pro is mentioned anywhere else.
private struct PurchasesSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let store = model.store
        Section {
            Button {
                Task { await store.restore() }
            } label: {
                HStack {
                    Text("Restore Purchases")
                    Spacer()
                    if store.isRestoring {
                        ProgressView()
                    }
                }
            }
            .disabled(store.isRestoring)
            .accessibilityIdentifier("purchases.restore")

            if let message = store.statusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Purchases")
        }
    }
}

/// Shown instead of Pro and Purchases in the Offline build, so it's obvious which build is installed.
/// Compiled only into that build (CI checks the text is in the Offline binary).
private struct OfflineBuildSection: View {
    var body: some View {
        #if OFFLINE
        Section {
            Label("Every feature is unlocked", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
        } header: {
            Text("Offline Build")
        } footer: {
            Text("This is a personal test build. Purchases are turned off and the app never goes online.")
        }
        #endif
    }
}

// MARK: - About

private struct AboutSection: View {
    var body: some View {
        Section {
            NavigationLink("Privacy Policy") {
                PrivacyPolicyView()
            }
            Link(destination: AppInfo.supportURL) {
                Label("Help & Feedback", systemImage: "arrow.up.right.square")
            }
            LabeledContent("Version", value: AppInfo.versionString)
        } header: {
            Text("About")
        } footer: {
            Text("No ads. No tracking. No account. Your answers never leave this device.")
        }
    }
}

enum AppInfo {
    /// Public help page (GitHub Pages). Change it here if you host support elsewhere.
    static let supportURL = URL(string: "https://tomnorush.github.io/Yes-No-Generator/support")!

    static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
