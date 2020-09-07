import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), viewData: ViewData(distance: "", recordedTime: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), viewData: ViewData(distance: "123", recordedTime: Date()))
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // TODO probably do formatting in the extension, not the app -> if user has not extension
        // formatting is a waste

        let prefs = PreferencesImpl()
        let json = JsonImpl()

        let now = Date()

        // refresh after 10s
        // oops, it seems to refresh at most each 5 minutes. so not usable for our app.
        guard let nextDate = Calendar.current.date(byAdding: .second, value: 10, to: now) else {
            // This shouldn't happen. But not letting it crash because widget has timestamp so not critical.
            // TODO what happens with crashes in widgets? If it doesn't bother the user, we should let it crash
            // to get reports
            log.e("Couldn't create date. Now: \(now)", .widget)
            return
        }

        guard let peerForWidgetStr = prefs.getString(key: .peerForWidget) else {
            log.d("No value for peerForWidget.", .widget)
            completion(Timeline(
                entries: [],
                policy: .after(nextDate)
            ))
            return
        }
        log.d("Widget read peer data from prefs: \(String(describing: peerForWidgetStr))", .widget)

        let peerForWidget: PeerForWidget = json.fromJson(json: peerForWidgetStr)
        let distStr = NumberFormatters.oneDecimal.string(from: peerForWidget.distance)

        let viewData = ViewData(distance: distStr ?? "", recordedTime: peerForWidget.recordedTime)

        completion(Timeline(
            entries: [SimpleEntry(date: now, viewData: viewData)],
            policy: .after(nextDate)
        ))
    }
}

struct ViewData {
    let distance: String
    let recordedTime: Date
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let viewData: ViewData
}

struct ploc_widgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Text(entry.viewData.distance)
            Text(entry.viewData.recordedTime, style: .time)
        }
    }
}

@main
struct ploc_widget: Widget {
    let kind: String = "ploc_widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ploc_widgetEntryView(entry: entry)
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
    }
}

struct ploc_widget_Previews: PreviewProvider {
    static var previews: some View {
        ploc_widgetEntryView(entry: SimpleEntry(date: Date(), viewData: ViewData(distance: "", recordedTime: Date())))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
