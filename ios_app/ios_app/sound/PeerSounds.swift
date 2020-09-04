import Foundation
import Combine

protocol PeerSounds {}

class PeerSoundsImpl: PeerSounds {
    private var distSoundCancellable: AnyCancellable?
    private var dirSoundCancellable: AnyCancellable?

    init(peerService: PeerService, soundPlayer: SoundPlayer) {
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
        // TODO
        .dir0
    }
}

private func sound(for distance: Float) -> Sound {
    // TODO
    .dist0
}
