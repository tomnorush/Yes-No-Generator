import SwiftUI
import UIKit
import YesNoKit

/// The whole app, most of the time: the answer is already on screen at launch,
/// and one tap anywhere gives a new one.
struct DecisionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @FocusState private var questionFocused: Bool
    @State private var showingHistory = false
    @State private var showingSettings = false
    @State private var copiedCount = 0
    @State private var showCopied = false

    private var palette: AnswerPalette {
        model.theme.palette(for: model.answer, in: colorScheme)
    }

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            VStack(spacing: 12) {
                ModePicker(mode: $model.mode, foreground: palette.foreground)
                questionField(text: $model.question)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            answerArea

            bottomBar
        }
        .foregroundStyle(palette.foreground)
        .tint(palette.foreground)
        .background {
            palette.background
                .ignoresSafeArea()
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.answer)
                .animation(.easeOut(duration: 0.2), value: model.theme)
        }
        .overlay(alignment: .top) {
            if showCopied {
                CopiedToast(foreground: palette.background, background: palette.foreground)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sensoryFeedback(trigger: model.answerCount) { _, _ in
            model.hapticsEnabled ? .impact(weight: .light) : nil
        }
        .sensoryFeedback(trigger: copiedCount) { _, _ in
            model.hapticsEnabled ? .success : nil
        }
        .onChange(of: model.answerCount) {
            AccessibilityNotification.Announcement(model.answer.spokenWord).post()
        }
        .onAppear { model.answerScreenAppeared() }
        .sheet(isPresented: $showingHistory) {
            HistoryView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    // MARK: - Question

    private func questionField(text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "questionmark.bubble")
                .accessibilityHidden(true)
            TextField(
                "Question",
                text: text,
                prompt: Text("Type a question (optional)").foregroundStyle(palette.foreground.opacity(0.75))
            )
            .focused($questionFocused)
            .submitLabel(.go)
            .onSubmit { model.ask() }
            .textInputAutocapitalization(.sentences)
            .accessibilityIdentifier("question")
            if !model.question.isEmpty {
                Button {
                    model.question = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .accessibilityLabel("Clear question")
            }
        }
        .font(.body)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(palette.foreground.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Answer

    private var answerArea: some View {
        Button {
            questionFocused = false
            model.reroll()
        } label: {
            VStack(spacing: 16) {
                Spacer(minLength: 0)
                Text(model.answer.word)
                    .font(.system(size: 132, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                    .padding(.horizontal, 24)
                    .keyframeAnimator(initialValue: 1.0, trigger: model.answerCount) { content, scale in
                        content.scaleEffect(reduceMotion ? 1 : scale)
                    } keyframes: { _ in
                        KeyframeTrack {
                            CubicKeyframe(0.9, duration: 0.06)
                            SpringKeyframe(1.0, duration: 0.3, spring: .snappy)
                        }
                    }

                if !model.effectiveOdds.isFair {
                    Label(model.effectiveOdds.summary(for: model.mode), systemImage: "slider.horizontal.3")
                        .font(.footnote.weight(.semibold))
                        .accessibilityLabel("Odds are tilted: \(model.effectiveOdds.summary(for: model.mode))")
                }

                if model.showsTapHint {
                    Text("Tap anywhere for a new answer")
                        .font(.subheadline)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("answer")
        .accessibilityLabel(model.answer.spokenWord)
        .accessibilityHint("Double-tap for a new answer")
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack {
            barButton("History", systemImage: "clock.arrow.circlepath", id: "history") {
                showingHistory = true
            }
            Spacer()
            barButton("Copy answer", systemImage: "doc.on.doc", id: "copy") {
                UIPasteboard.general.string = model.shareText
                copiedCount += 1
                withAnimation(.snappy) { showCopied = true }
                let token = copiedCount
                Task {
                    try? await Task.sleep(for: .seconds(1.4))
                    if token == copiedCount {
                        withAnimation(.snappy) { showCopied = false }
                    }
                }
            }
            Spacer()
            ShareLink(item: model.shareText) {
                barIcon("square.and.arrow.up")
            }
            .accessibilityLabel("Share answer")
            .accessibilityIdentifier("share")
            Spacer()
            barButton("Settings", systemImage: "gearshape", id: "settings") {
                showingSettings = true
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 8)
    }

    private func barButton(
        _ title: LocalizedStringKey,
        systemImage: String,
        id: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            barIcon(systemImage)
        }
        .accessibilityLabel(title)
        .accessibilityIdentifier(id)
    }

    private func barIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.title3.weight(.semibold))
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
    }
}

// MARK: - Mode picker

/// Two-way or three-way, right on the main screen instead of buried in a menu.
private struct ModePicker: View {
    @Binding var mode: AnswerMode
    let foreground: Color

    var body: some View {
        HStack(spacing: 4) {
            option(.yesNo, title: "Yes / No")
            option(.yesNoMaybe, title: "Yes / No / Maybe")
        }
        .padding(4)
        .background(foreground.opacity(0.1), in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Answer type")
    }

    private func option(_ value: AnswerMode, title: LocalizedStringKey) -> some View {
        let selected = mode == value
        return Button {
            mode = value
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background {
                    if selected {
                        Capsule().fill(foreground.opacity(0.18))
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(value == .yesNo ? "mode.yesNo" : "mode.yesNoMaybe")
    }
}

private struct CopiedToast: View {
    let foreground: Color
    let background: Color

    var body: some View {
        Label("Copied", systemImage: "checkmark")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(background, in: Capsule())
            .accessibilityAddTraits(.isStaticText)
    }
}

#Preview {
    DecisionView()
        .environment(AppModel.shared)
}
