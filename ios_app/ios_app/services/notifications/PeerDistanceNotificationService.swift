import Foundation
import Combine
import CombineExt

struct PeerWithBlockedStatus {
    let peer: DetectedPeer
    let blocked: Bool
}

struct PeerWithCloseStatus: Equatable {
    let peer: DetectedPeer
    let close: Bool
}

// Show notification when at a distance smaller than this
private let distanceThresholdMeters: Float = 10

// Block showing a new notification for this time
private let timeToShowNotificationAgain: TimeInterval = 30 * 60

class PeerDistanceNotificationService {
    private let peerService: DetectedPeerService
    private let notificationService: NotificationService

    private let notificationsBlockedSubject = CurrentValueSubject<Bool, Never>(false)

    private var closePeerCancellable: Cancellable?

    // Don't show a notification again x secs after showing one
    // Prevents multiple notifications when the user is at the range's edges or walks in an out
    private var timeToShowNotificationAgainTimer: Timer?

    init(peerService: DetectedPeerService, notificationService: NotificationService) {
        self.peerService = peerService
        self.notificationService = notificationService

        closePeerCancellable = peerService.peer
            .compactMap { $0 } // filter out nil (not in range/unavailable) peer
            .withLatestFrom(notificationsBlockedSubject, resultSelector: { peer, blocked in
                PeerWithBlockedStatus(peer: peer, blocked: blocked)
            })
            .map { peer -> PeerWithCloseStatus in
                if let dist = peer.peer.dist, peer.blocked == false {
                    // != 0: sometimes we get 0 unexpectedly TODO investigate
                    if dist != 0 && dist < distanceThresholdMeters {
                        return PeerWithCloseStatus(peer: peer.peer, close: true)
                    } else {
                        return PeerWithCloseStatus(peer: peer.peer, close: false)
                    }
                } else {
                    return PeerWithCloseStatus(peer: peer.peer, close: false)
                }
            }
            // we want [not close -> close] event, so we remove duplicates (stream will be e.g. false, true, false, true...)
            // and filter by close
            .removeDuplicates(by: { p1, p2 in
                p1.close == p2.close
            })
            .filter { $0.close }
            .map { $0.peer }
            .sink { [weak self] peer in
                self?.onPeerClose(peer)
            }
    }

    private func onPeerClose(_ peer: DetectedPeer) {
        log.i("Peer close! showing notification", .notifications)
        notificationsBlockedSubject.send(true)
        timeToShowNotificationAgainTimer = Timer.scheduledTimer(timeInterval: timeToShowNotificationAgain,
                                                                target: self, selector: #selector(fireTimer),
                                                                userInfo: nil, repeats: false)
        showIsCloseNotification(peer: peer)
    }

    @objc private func fireTimer() {
        log.d("Unblocking peer close notification after \(timeToShowNotificationAgain)s", .notifications)
        timeToShowNotificationAgainTimer = nil
        notificationsBlockedSubject.send(false)
    }

    private func showIsCloseNotification(peer: DetectedPeer) {
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
