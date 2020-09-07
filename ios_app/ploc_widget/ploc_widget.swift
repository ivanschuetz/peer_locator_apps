import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        let crypto = CryptoImpl()
        let json = JsonImpl()
        let sessionApi = CoreImpl()
        let keyChain = KeyChainImpl(json: json)
        let sessionService = SessionServiceImpl(sessionApi: sessionApi, crypto: crypto, keyChain: keyChain)

        let bleIdService = BleIdServiceImpl(crypto: crypto, json: json, sessionService: sessionService, keyChain: keyChain)
        let per = BlePeripheralImpl(idService: bleIdService)
        per.requestStart()
        let central = BleCentralImpl(idService: bleIdService)
        central.requestStart()
        
        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct ploc_widgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        Text(entry.date, style: .time)
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
        ploc_widgetEntryView(entry: SimpleEntry(date: Date()))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
