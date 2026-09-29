import SwiftUI
import WidgetKit

/// A watch-face complication that opens the app straight to a fresh answer.
/// It shows no answer itself: a static face can't reroll, and a stale answer would mislead.
@main
struct YesNoComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "YesNoComplication", provider: Provider()) { _ in
            ComplicationView()
                .widgetURL(URL(string: "yesno://ask"))
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Yes or No")
        .description("Tap for an instant answer.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}

private struct Entry: TimelineEntry {
    let date: Date
}

private struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now)], policy: .never))
    }
}

private struct ComplicationView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCorner:
            Image(systemName: "questionmark")
                .font(.title3.weight(.black))
                .widgetLabel("Yes or No")
        case .accessoryInline:
            Label("Yes or No?", systemImage: "questionmark.circle")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Yes or No")
                    .font(.headline)
                    .widgetAccentable()
                Text("Tap for an answer")
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            ZStack {
                AccessoryWidgetBackground()
                Text("Y/N")
                    .font(.system(.body, design: .rounded).weight(.black))
                    .minimumScaleFactor(0.6)
                    .widgetAccentable()
            }
        }
    }
}
