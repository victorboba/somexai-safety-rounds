import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry { SnapshotEntry(date: .now, snapshot: .placeholder) }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)
        completion(Timeline(entries: [SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load())], policy: .after(midnight)))
    }
}

struct SafetyRoundsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry
    private var s: WidgetSnapshot { entry.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppConfig.appName).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if s.totalAssets == 0 {
                Text("Add equipment to start").font(.headline)
            } else if s.overdue > 0 {
                Label("\(s.overdue) overdue", systemImage: "exclamationmark.circle.fill").font(.headline).foregroundStyle(.red)
            } else if s.dueThisWeek > 0 {
                Label("\(s.dueThisWeek) due this week", systemImage: "clock.fill").font(.headline).foregroundStyle(.orange)
            } else {
                Label("All up to date", systemImage: "checkmark.circle.fill").font(.headline).foregroundStyle(.green)
            }
            if let tag = s.nextDueTag, let date = s.nextDueDate {
                Text("Next: \(tag) · \(date.formatted(.dateTime.month(.abbreviated).day()))").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            HStack {
                Text("\(s.totalAssets) items").font(.caption2)
                if family != .systemSmall, let last = s.lastInspectionDate {
                    Spacer()
                    Text("Last check \(last.formatted(.dateTime.month(.abbreviated).day()))").font(.caption2)
                }
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct SafetyRoundsWidget: Widget {
    let kind = "SafetyRoundsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { SafetyRoundsWidgetView(entry: $0) }
            .configurationDisplayName(AppConfig.appName)
            .description("Overdue and upcoming safety inspections.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct SafetyRoundsWidgetBundle: WidgetBundle {
    var body: some Widget { SafetyRoundsWidget() }
}
