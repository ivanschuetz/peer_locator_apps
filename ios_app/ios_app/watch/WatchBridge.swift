import Foundation
import WatchConnectivity

protocol WatchBridge {
    func send(msg: [String: Any])
}

class ConnectivityHandler : NSObject, WatchBridge, WCSessionDelegate {
    private let session: WCSession = .default

    override init() {
        super.init()

        self.session.delegate = self
        self.session.activate()

        log.d("Paired watch: \(self.session.isPaired), watch app installed: \(self.session.isWatchAppInstalled), " +
                "isSupported: \(WCSession.isSupported()), isReachable: \(self.session.isReachable), " +
                "activationState: \(self.session.activationState.rawValue)", .watch)
    }

    func send(msg: [String: Any]) {
        session.sendMessage(msg, replyHandler: nil, errorHandler: { error in
            log.e("Error sending message to watch: \(error)", .watch)
        })
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        log.d("activationDidCompleteWith activationState:\(activationState.rawValue) error:\(String(describing: error))", .watch)
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        log.d("sessionDidBecomeInactive: \(session)", .watch)
    }

    func sessionDidDeactivate(_ session: WCSession) {
        log.d("sessionDidDeactivate: \(session)", .watch)
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        log.d("sessionWatchStateDidChange: \(session)", .watch)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        log.d("didReceiveMessage: \(message)", .watch)
    }
}
