import Foundation

protocol Json {
    func toJson<T: Encodable>(encodable: T) -> String
    func fromJson<T: Decodable>(json: String) -> T
}

class JsonImpl: Json {

    func toJson<T: Encodable>(encodable: T) -> String {
        let data = try! JSONEncoder().encode(encodable)
        return String(data: data, encoding: .utf8)!
    }

    func fromJson<T: Decodable>(json: String) -> T {
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        return try! decoder.decode(T.self, from: data)
    }
}
