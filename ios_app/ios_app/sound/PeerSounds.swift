import Foundation
import Combine

protocol PeerSounds {}

class PeerSoundsImpl: PeerSounds {
    private var distSoundCancellable: AnyCancellable?
    private var dirSoundCancellable: AnyCancellable?

    init(peerService: DetectedPeerService, soundPlayer: SoundPlayer) {
        let peerObservable = peerService.peer
            // TODO RunLoop.main maybe wrong here? probably for UI updates?
            .throttle(for: 5, scheduler: RunLoop.main, latest: false)

        distSoundCancellable = peerObservable
            .compactMap { $0?.dist.map { sound(for: $0) } }
//            .removeDuplicates() // use this when the sound is infinite, no need to restart
            .sink {
                soundPlayer.play(sound: $0)
            }

        dirSoundCancellable = peerObservable
            .compactMap { $0?.dir.map { $0.sound() } }
            .sink {
                soundPlayer.play(sound: $0)
            }
    }
}

private extension Direction {
    func sound() -> Sound {
        let angle = radiansTodegrees(toAngle())
        let hour = calculateHour(angleDegrees: angle)
        switch hour {
        case .h0: return .dir0
        case .h1: return .dir1
        case .h2: return .dir2
        case .h3: return .dir3
        case .h4: return .dir4
        case .h5: return .dir5
        case .h6: return .dir6
        case .h7: return .dir7
        case .h8: return .dir8
        case .h9: return .dir9
        case .h10: return .dir10
        case .h11: return .dir11
        }
    }

    private func calculateHour(angleDegrees: Double) -> Hour {
        switch Int(round(angleDegrees)) {
        case 0...15: return .h0
        case 16...45: return .h1
        case 46...75: return .h2
        case 76...105: return .h3
        case 106...135: return .h4
        case 136...165: return .h5
        case 166...195: return .h6
        case 196...225: return .h7
        case 226...255: return .h8
        case 256...285: return .h9
        case 286...315: return .h10
        case 316...345: return .h11
        case 346...360: return .h0
        default: fatalError("Illegal angle: \(angleDegrees), rounded: \(Int(round(angleDegrees)))")
        }
    }
}

private enum Hour {
    case h0, h1, h2, h3, h4, h5, h6, h7, h8, h9, h10, h11
}

// TODO test that this doesn't return > 360 (radians)
private func radiansTodegrees(_ number: Double) -> Double {
    return number * 180 / .pi
}

private func sound(for distance: Float) -> Sound {
    if distance < 0 {
        // TODO check whether this can happen. If yes maybe we should return optional sound and interrupt playing?
        // or say e.g. "error"?
        fatalError("Negative distance")
    }
    switch Int(floor(distance)) {
    case 0: return .dist0
    case 1: return .dist1
    case 2: return .dist2
    case 3: return .dist3
    case 4: return .dist4
    case 5: return .dist5
    case 6: return .dist6
    case 7: return .dist7
    case 8: return .dist8
    case 9: return .dist9
    // For > 90m we just keep playing the 90m sound
    default: return .dist9
    }
}
