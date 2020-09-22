import Foundation

struct RetryData<T> {
    let data: T
    let count: Int
    let maxCount = 3

    private init(_ data: T, count: Int) {
        self.data = data
        self.count = count
    }

    init(_ data: T) {
        self.init(data, count: 0)
    }

    func increment() -> RetryData {
        RetryData(data, count: count + 1)
    }

    func shouldRetry() -> Bool {
        count < maxCount
    }
}
