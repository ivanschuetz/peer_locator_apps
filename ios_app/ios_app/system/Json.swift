import Foundation

protocol Json {
    func toJsonData<T: Encodable>(encodable: T) -> Data
    func toJson<T: Encodable>(encodable: T) -> String

    func fromJsonData<T: Decodable>(json: Data) -> T
    func fromJson<T: Decodable>(json: String) -> T
}

class JsonImpl: Json {
    func toJsonData<T>(encodable: T) -> Data where T : Encodable {
        try! JSONEncoder().encode(encodable)
    }

    func fromJsonData<T>(json: Data) -> T where T : Decodable {
        let decoder = JSONDecoder()
        return try! decoder.decode(T.self, from: json)
    }

    func toJson<T: Encodable>(encodable: T) -> String {
        let data = toJsonData(encodable: encodable)
        return String(data: data, encoding: .utf8)!
    }

    func fromJson<T: Decodable>(json: String) -> T {
        let data = json.data(using: .utf8)!
        return fromJsonData(json: data)
    }
}
