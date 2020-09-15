enum DetectedPeerSource {
    case ble, nearby
}

struct Location: Equatable {
    let x: Float
    let y: Float
}

struct DetectedPeer: Equatable, Hashable {
    let name: String
    // TODO think about optional distance (and other field). if dist isn't set, should the point disappear or show
    // the last loc with a "stale" status? requires to clear: can dist disappear only when out of range?
    // Note that this applies only to Nearby. BLE dist (i.e. rssi) is maybe always set, but check this too.
    let dist: Float?
    let loc: Location?
    let dir: Direction?
    let src: DetectedPeerSource

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

struct Direction: Equatable {
    let x: Float
    let y: Float
}
