import Foundation
import Combine

protocol PeerForWidgetRecorder {}

class PeerForWidgetRecorderImpl: PeerForWidgetRecorder {
    private var peerCancellable: Cancellable?

    init(peerService: DetectedPeerService, preferences: Preferences, json: Json) {
        peerCancellable = peerService.peer
            .throttle(for: 10, scheduler: RunLoop.main, latest: false)
            .sink { peer in
                if let peer = peer, let dist = peer.dist {
                    log.d("Writing peer data in prefs for widget: \(dist)", .widget)

                    let json = json.toJson(encodable: PeerForWidget(distance: dist, recordedTime: Date()))
                    preferences.putString(key: .peerForWidget, value: json)
                }
            }
    }
}
