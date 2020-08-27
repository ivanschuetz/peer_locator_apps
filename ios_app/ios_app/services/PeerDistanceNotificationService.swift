import Foundation
import Combine

class PeerDistanceNotificationService {
    private let peerService: PeerService
    private let notificationService: NotificationService

    private let distanceThreshold: Float = 10

    private var closePeerCancellable: Cancellable?

    init(peerService: PeerService, notificationService: NotificationService) {
        self.peerService = peerService
        self.notificationService = notificationService

        closePeerCancellable = peerService.peer
            .filter { [weak self] peer in guard let self = self else { return false }
                if let dist = peer.dist {
                    // != 0: sometimes we get 0 unexpectedly TODO investigate
                    return dist != 0 && dist < self.distanceThreshold
                } else {
                    return false
                }
            }
            .removeDuplicates().sink { [weak self] peer in
            self?.showIsCloseNotification(peer: peer)
        }
    }

    private func showIsCloseNotification(peer: Peer) {
        guard let dist = peer.dist else {
            // We should be in this method only if peer has distance.
            log.e("Invalid state: peer: \(peer) doesn't have distance.", .notifications)
            return
        }

        let notificationData = NotificationData(id: .peerClose,
                                                title: "Contact proximity notification",
                                                body: "\(peer.name) is \(dist)m away!")
        notificationService.showNotification(data: notificationData)
    }
}
