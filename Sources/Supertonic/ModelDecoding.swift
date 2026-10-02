import Foundation

func decode<Value: Decodable>(_ type: Value.Type, from url: URL) throws -> Value {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(type, from: Data(contentsOf: url))
}
