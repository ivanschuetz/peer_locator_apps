import Foundation
import Combine

protocol WatchEventsForwarder {}

class WatchEventsForwarderImpl: WatchEventsForwarder {
    private let sessionService: CurrentSessionService
    private let watchBridge: WatchBridge

    private var sessionCancellable: Cancellable?
    private var peerCancellable: Cancellable?

    init(sessionService: CurrentSessionService, watchBridge: WatchBridge, peerService: DetectedPeerService) {
        self.sessionService = sessionService
        self.watchBridge = watchBridge

        sessionCancellable = sessionService.session.sink { sessionRes in
            switch sessionRes {
            case .success(let session):
                let msg = ["session": session as Any]
                log.d("Sending session data to watch: \(msg)", .watch)
                watchBridge.send(msg: msg)
            case .failure(let e):
                // If there are issues retrieving session this screen normally shouldn't be presented
                // TODO ensure that only one message of a type shows at a time
                let msg = "Couldn't retrieve session: \(e)"
                log.e(msg, .watch)
                // TODO how to display errors communicating with watch: maybe a badge somewhere
//                uiNotifier.show(.error(msg))
            }
        }

        peerCancellable = peerService.peer.sink { peer in
            let msg = ["peer": peer as Any]
            log.d("Sending peer to watch: \(msg)", .watch)
            watchBridge.send(msg: msg)
        }

        // Testing
//        let peer = DetectedPeer(name: "foo", dist: 123, loc: nil, dir: nil, src: .ble)
//        let msg = ["peer": peer as Any]
//        log.d("Sending peer to watch: \(msg)", .watch)
//        watchBridge.send(msg: msg)
    }
}
