import Foundation
import Combine

protocol LocationVoice {}

class LocationVoiceImpl: LocationVoice {
    private var peerCancellable: AnyCancellable?

    init(peerService: DetectedPeerService, voice: Voice) {
        peerCancellable = peerService.peer
            // TODO RunLoop.main maybe wrong here? probably for UI updates?
            .throttle(for: 5, scheduler: RunLoop.main, latest: false)
            .sink { peerMaybe in
                if let peer = peerMaybe {
                    if let dist = peer.dist {
                        if let formatted = NumberFormatters.oneDecimal.string(from: dist) {
                            voice.say("\(formatted) meters")
                        } else {
                            log.e("Invalid state: couldn't format dist: \(dist)", .voice)
                            voice.say("Unexpected error")
                        }
                    }
                } else {
                    voice.say("Peer unavailable")
                }
            }
    }
}
