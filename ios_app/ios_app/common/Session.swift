import Foundation

struct Session {
    let id: String
    let keys: [PublicKey]
}

struct PublicKey {
    let str: String
}
