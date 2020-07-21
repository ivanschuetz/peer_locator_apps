import Foundation

let cachingLog = CachingLog()
let log: Log = CompositeLog(
    logs: cachingLog, ConsoleLog()
)

class CompositeLog: Log {
    private let logs: [LogNonVariadicTags]

    init(logs: LogNonVariadicTags...) {
        self.logs = logs
        for log in logs {
            log.setup()
        }
    }

    func setup() {
        for log in logs {
            log.setup()
        }
    }

    func v(_ message: String, _ tags: LogTag...) {
        for log in logs {
            log.v(message, tags)
        }
    }

    func d(_ message: String, _ tags: LogTag...) {
        for log in logs {
            log.d(message, tags)
        }
    }

    func i(_ message: String, _ tags: LogTag...) {
        for log in logs {
            log.i(message, tags)
        }
    }

    func w(_ message: String, _ tags: LogTag...) {
        for log in logs {
            log.w(message, tags)
        }
    }

    func e(_ message: String, _ tags: LogTag...) {
        for log in logs {
            log.e(message, tags)
        }
    }
}
