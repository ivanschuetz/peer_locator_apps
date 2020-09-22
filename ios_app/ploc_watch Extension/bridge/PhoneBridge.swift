import WatchKit
import Foundation
import WatchConnectivity
import Combine

protocol PhoneBridge {
    var messages: AnyPublisher<[String: Any], Never> { get }

    func sendMessage(_ message: [String: Any])
}

class PhoneBridgeImpl: NSObject, WCSessionDelegate, PhoneBridge {
    private let messagesSubject = PassthroughSubject<[String: Any], Never>()
    lazy var messages = messagesSubject.eraseToAnyPublisher()

    private let session: WCSession = .default

    override init() {
        super.init()

        session.delegate = self
        session.activate()

        log.d("WCSession activated: app is installed: \(session.isCompanionAppInstalled), isReachable: " +
                "\(session.isReachable), activationState: \(session.activationState.rawValue), " +
            "iOSDeviceNeedsUnlockAfterRebootForReachability: \(session.iOSDeviceNeedsUnlockAfterRebootForReachability)")
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        log.d("Watch received message: \(message)")
        messagesSubject.send(message)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        log.d("activationDidCompleteWith activationState:\(activationState.rawValue) error:\(String(describing: error))")
    }

    func sendMessage(_ message: [String: Any]) {
//        session.sendMessage(["request": "date"],
        session.sendMessage(message,
            replyHandler: { response in
//                self.messages.append("Reply: \(response)")
            },
            errorHandler: { error in
                log.e("Error sending message: \(error)")
            }
        )
    }
}

protocol PhoneBridgeDelegate {
    func onMessage(_ message: [String: Any])
}
