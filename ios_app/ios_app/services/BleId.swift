import Foundation

struct BleId: CustomDebugStringConvertible, Hashable {
    let data: Data

    func hash(into hasher: inout Hasher) {
        hasher.combine(data)
    }

    private let encoding: String.Encoding = .utf8

    var debugDescription: String {
        str()
    }

    init?(str: String) {
        if let data = str.data(using: encoding) {
            self.data = data
        } else {
            return nil
        }
    }

    init?(data: Data) {
        // Verify that data has expected format
        if String(data: data, encoding: encoding) == nil {
            return nil
        }
        self.data = data
    }

    func str() -> String {
        // Unwrap: We know in this struct that data was generated from a string with the same encoding.
        String(data: data, encoding: encoding)!
    }

    static func random() -> BleId {
        // Unwrap: We know here that it's safe as UUID is always utf8
        BleId(str: UUID().uuidString)!
    }
}
