enum LogTag {
    case
        // Note: logs tagged with blec/blep will have no ble tag. We can filter for the start text (`[ble`) to include all.
        ble, blec, blep,
        ui, peer, nearby, notifications, session, env, core, val, deeplink, watch, voice, bg, widget,
        // colocated pairing
        cp
}

protocol Log {
    func setup()
    func v(_ message: String, _ tags: LogTag...)
    func d(_ message: String, _ tags: LogTag...)
    func i(_ message: String, _ tags: LogTag...)
    func w(_ message: String, _ tags: LogTag...)
    func e(_ message: String, _ tags: LogTag...)
}

// Workaround: Swift doesn't support yet passing varargs to another varargs parameter
protocol LogNonVariadicTags {
    func setup()
    func v(_ message: String, _ tags: [LogTag])
    func d(_ message: String, _ tags: [LogTag])
    func i(_ message: String, _ tags: [LogTag])
    func w(_ message: String, _ tags: [LogTag])
    func e(_ message: String, _ tags: [LogTag])
}

enum LogLevel {
    case v
    case d
    case i
    case w
    case e
}
