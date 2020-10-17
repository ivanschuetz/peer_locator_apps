import Foundation

protocol Json {
    func toJsonData<T: Encodable>(encodable: T) -> Result<Data, ServicesError>
    func toJson<T: Encodable>(encodable: T) -> Result<String, ServicesError>

    func fromJsonData<T: Decodable>(json: Data) -> Result<T, ServicesError>
    func fromJson<T: Decodable>(json: String) -> Result<T, ServicesError>
}

class JsonImpl: Json {
    func toJsonData<T>(encodable: T) -> Result<Data, ServicesError> where T : Encodable {
        do {
            return .success(try JSONEncoder().encode(encodable))
        } catch (let e) {
            return .failure(.general("Error encoding data to json: \(e), encodable: \(encodable)"))
        }
    }

    func fromJsonData<T>(json: Data) -> Result<T, ServicesError> where T : Decodable {
        let decoder = JSONDecoder()
        do {
            return .success(try decoder.decode(T.self, from: json))
        } catch (let e) {
            return .failure(.general("Error decoding json: \(e), json: \(json)"))
        }
    }

    func toJson<T: Encodable>(encodable: T) -> Result<String, ServicesError> {
        toJsonData(encodable: encodable).flatMap { data in
            if let str = String(data: data, encoding: .utf8) {
                return .success(str)
            } else {
                return .failure(.general("Unexpected data encoding for: \(data)"))
            }
        }
    }

    func fromJson<T: Decodable>(json: String) -> Result<T, ServicesError> {
        if let data = json.data(using: .utf8) {
            return fromJsonData(json: data)
        } else {
            return .failure(.general("Unexpected string encoding for: \(json)"))
        }
    }
}
