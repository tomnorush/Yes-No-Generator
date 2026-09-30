import SwiftUI
import WatchKit
import YesNoKit

private let modeKey = "watch.mode"

/// A decision from the wrist: the answer is there on launch; tap, turn the crown,
/// or double-tap your fingers (Series 9 and later) for another.
struct WatchDecisionView: View {
    @AppStorage(modeKey) private var modeRaw = AnswerMode.yesNo.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Picked before the first frame so the answer is simply there when the app opens.
    @State private var answer: Answer
    @State private var answerCount = 0
    @State private var crown = 0.0
    @State private var crownAtLastAnswer = 0.0
    @State private var backgroundedAt: Date?

    init() {
        let savedMode = AnswerMode(rawValue: UserDefaults.standard.string(forKey: modeKey) ?? "") ?? .yesNo
        _answer = State(initialValue: Decider.decide(mode: savedMode))
    }

    private var mode: AnswerMode { AnswerMode(rawValue: modeRaw) ?? .yesNo }

    var body: some View {
        NavigationStack {
            Button(action: ask) {
                // Copied out of the environment: the animator's closure can't read view state directly.
                let bounces = !reduceMotion
                VStack(spacing: 4) {
                    Text(answer.word)
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                        .keyframeAnimator(initialValue: 1.0, trigger: answerCount) { content, scale in
                            content.scaleEffect(bounces ? scale : 1)
                        } keyframes: { _ in
                            KeyframeTrack {
                                CubicKeyframe(0.88, duration: 0.06)
                                SpringKeyframe(1.0, duration: 0.3, spring: .snappy)
                            }
                        }
                    Text("Tap for another")
                        .font(.footnote)
                        .opacity(0.8)
                }
                .foregroundStyle(WatchPalette.foreground(for: answer))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .modifier(PrimaryHandGesture())
            .accessibilityLabel(answer.spokenWord)
            .accessibilityHint("Double-tap for a new answer")
            .focusable()
            .focusEffectDisabled()
            .digitalCrownRotation(
                $crown,
                from: -100_000,
                through: 100_000,
                by: 1,
                sensitivity: .low,
                isContinuous: false,
                isHapticFeedbackEnabled: false
            )
            .onChange(of: crown) { _, value in
                // One new answer per deliberate turn, not a flurry while the crown spins.
                if abs(value - crownAtLastAnswer) >= 6 {
                    crownAtLastAnswer = value
                    ask()
                }
            }
            .background(WatchPalette.background(for: answer).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        modeRaw = (mode == .yesNo ? AnswerMode.yesNoMaybe : .yesNo).rawValue
                        ask()
                    } label: {
                        Text(mode == .yesNo ? "Y/N" : "Y/N/M")
                            .font(.system(.footnote, design: .rounded).weight(.bold))
                    }
                    .accessibilityLabel(mode == .yesNo ? "Answer type: Yes or No" : "Answer type: Yes, No or Maybe")
                    .accessibilityHint("Double-tap to switch")
                }
            }
        }
        .onOpenURL { _ in
            // Opened from the complication: always a fresh answer.
            ask()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                backgroundedAt = Date()
            case .active:
                if SessionFreshness.needsFreshAnswer(backgroundedAt: backgroundedAt) {
                    ask()
                }
                backgroundedAt = nil
            default:
                break
            }
        }
    }

    private func ask() {
        answer = Decider.decide(mode: mode)
        answerCount += 1
        WKInterfaceDevice.current().play(.click)
    }
}

/// Double-tap gesture (watchOS 11+, Apple Watch Series 9 / Ultra 2 and later) triggers the answer button.
private struct PrimaryHandGesture: ViewModifier {
    func body(content: Content) -> some View {
        if #available(watchOS 11.0, *) {
            content.handGestureShortcut(.primaryAction)
        } else {
            content
        }
    }
}

/// The watch is always dark, so it uses the dark Classic colors.
enum WatchPalette {
    static func background(for answer: Answer) -> Color {
        switch answer {
        case .yes: Color(red: 0.05, green: 0.20, blue: 0.10)
        case .no: Color(red: 0.24, green: 0.07, blue: 0.06)
        case .maybe: Color(red: 0.22, green: 0.17, blue: 0.03)
        }
    }

    static func foreground(for answer: Answer) -> Color {
        switch answer {
        case .yes: Color(red: 0.48, green: 0.89, blue: 0.63)
        case .no: Color(red: 1.0, green: 0.60, blue: 0.56)
        case .maybe: Color(red: 1.0, green: 0.82, blue: 0.40)
        }
    }
}
