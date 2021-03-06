import Foundation

class ConsoleLog: LogNonVariadicTags {
    func setup() {}

    func v(_ message: String, _ tags: [LogTag]) {
        log(level: .v, message: message, tags: tags)
    }

    func d(_ message: String, _ tags: [LogTag]) {
        log(level: .d, message: message, tags: tags)
    }

    func i(_ message: String, _ tags: [LogTag]) {
        log(level: .i, message: message, tags: tags)
    }

    func w(_ message: String, _ tags: [LogTag]) {
        log(level: .w, message: message, tags: tags)
    }

    func e(_ message: String, _ tags: [LogTag]) {
        log(level: .e, message: message, tags: tags)
    }

    private func log(level: LogLevel, message: String, tags: [LogTag]) {
        if tags.contains(.watch) { return } // TODO remove
        if tags.contains(.nearby) { return } // TODO remove
        if tags.contains(.peer) { return } // TODO remove

        let tagsStr = tags.map { "[\($0)]"}.joined(separator: " ")
        let tagPart = tagsStr.isEmpty ? "" : tagsStr + " "

        let levelStr: String = {
            switch level {
            case .v: return "📓"
            case .d: return "📗"
            case .i: return "📘"
            case .w: return "📙"
            case .e: return "📕"
            }
        }()

        NSLog(levelStr + " LOGGER " + tagPart + message)
    }
}
