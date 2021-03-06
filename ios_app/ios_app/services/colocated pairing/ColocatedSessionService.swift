import Foundation
import Combine

protocol ColocatedSessionService {
    func generatePassword() -> ColocatedPeeringPassword
}

class ColocatedSessionServiceImpl: ColocatedSessionService {
    private let meetingValidation: BleValidation
    private let colocatedPairing: BleColocatedPairing
    private let peerMediator: ColocatedPeerMediator
    private let uiNotifier: UINotifier
    private let sessionService: CurrentSessionService
    private let passwordProvider: ColocatedPasswordProvider
    private let localSessionManager: LocalSessionManager

    private var receivedPasswordCancellable: Cancellable?
    private var receivedPeerKeyCancellable: Cancellable?
    private var errorWritingPublicKeyCancellable: AnyCancellable?

    private let shouldReplyWithMyKey = CurrentValueSubject<Bool, Never>(true)

    init(meetingValidation: BleValidation, colocatedPairing: BleColocatedPairing,
         passwordProvider: ColocatedPasswordProvider, passwordService: ColocatedPairingPasswordService,
         peerMediator: ColocatedPeerMediator, uiNotifier: UINotifier, sessionService: CurrentSessionService,
         localSessionManager: LocalSessionManager) {
        self.meetingValidation = meetingValidation
        self.colocatedPairing = colocatedPairing
        self.peerMediator = peerMediator
        self.uiNotifier = uiNotifier
        self.sessionService = sessionService
        self.passwordProvider = passwordProvider
        self.localSessionManager = localSessionManager

        // TODO(pmvp) error handling during close pairing:
        // - received corrupted data
        // - timeout writing
        // -> investigate if ble handles this for us somehow
        // -> possible: retry 3 times, if fails, offer user to retry or re-start the pairing (with a different pw)
        // generally, review this whole file. It's just a happy path poc.

        receivedPeerKeyCancellable = colocatedPairing.publicKey
            .combineLatest(shouldReplyWithMyKey.eraseToAnyPublisher())
            .sink { [weak self] key, shouldReply in
                self?.handleReceivedKey(key: key, shouldReply: shouldReply)
        }

        receivedPasswordCancellable = passwordService.password
            .sink { [weak self] in
                self?.handleReceivedPassword($0)
            }

        errorWritingPublicKeyCancellable = colocatedPairing.errorSendingKey.sink { error in
            // TODO(pmvp) dialog offering to retry? and/or exit->create/join session again? or toggle the device's ble, restart the app?
            // note that this will be triggered after the automatic low level retry (when implemented)
            log.e("Error seding public key to peer: \(error)", .cp)
            uiNotifier.show(.error("Bluetooth communication error. Please try again."))
        }
    }

    func generatePassword() -> ColocatedPeeringPassword {
        // TODO(pmvp) this side effect is quick and dirty, probably better way to reset this?
        shouldReplyWithMyKey.send(true)

        // TODO(pmvp)  random, qr code
        return ColocatedPeeringPassword(value: "123")
    }

    private func handleReceivedKey(key: SerializedEncryptedPublicKey, shouldReply: Bool) {
        if let password = passwordProvider.password() {
            handleReceivedKey(key: key, password: password, shouldReply: shouldReply)
        } else {
            log.e("Invalid state? peer sent us their public key but we haven't stored a pw.", .cp)
            uiNotifier.show(.error("Unknown error. Please try again"))
            // TODO(pmvp)  better handling
        }
    }

    private func handleReceivedKey(key: SerializedEncryptedPublicKey, password: ColocatedPeeringPassword,
                                   shouldReply: Bool) {

        let encryptedKey = key.toEncryptedPublicKey()

        guard let peer = peerMediator.processPeer(key: encryptedKey, password: password) else {
            log.e("Received an invalid peer public key: \(encryptedKey). Exit.", .cp)
            return
        }

        // TODO(pmvp) "transactionally". Currently we store first the peers, if success then our session data...
        // we should store them ideally together. Prob after refactor that merges session data and peers.
        switch localSessionManager.savePeer(peer) {
        case .success:
            if shouldReply {
                log.d("Received data from peer. Will send back my data", .cp)
                initializeMySessionDataAndSendPublicKey(password: password)
            }

            log.d("Received and stored peer's public key. Validating peer (meeting).", .cp)
            // more quick "happy path"... directly after receiving peer's key, validate TODO review
            _ = meetingValidation.validatePeer()

            // TODO(pmvp) we probably should ACK having peer's keys (like we do with the backend)
            // otherwise one peer may show success while the other doesn't have the peer key, which is critical
            // (for colocated mostly not, as they'd notice immediately, but still, at least for correctness)
            // ack like everything else would probably need a retry too
            // for now we will mark here directly the session as ready

            // Note that this, by setting the current session controls the root navigation

            switch localSessionManager.saveIsReady(true) {
            case .success(let session):
                sessionService.setSessionState(.result(Result.success(session).map { .isSet($0) }))
            case .failure(let e):
                log.e("Error updating session isReady: \(e)", .cp)
                sessionService.setSessionState(.result(.failure(e)))
            }

        case .failure(let e):
            log.e("Couldn't save peer key: \(e)", .cp)
        }
    }

    private func handleReceivedPassword(_ password: ColocatedPeeringPassword) {
        // The one receiving the password deeplink sends the public key immediately, so when we receive
        // peer's public key we don't send it again.
        shouldReplyWithMyKey.send(false)
        // TODO(pmvp)  probably should be set to false only if initializeMySessionDataAndSendPublicKey succeeds,
        // check flow
        log.d("Received password from peer. Will send my data.", .cp)
        initializeMySessionDataAndSendPublicKey(password: password)
    }

    private func initializeMySessionDataAndSendPublicKey(password: ColocatedPeeringPassword) {
        let result = localSessionManager.initLocalSession(iCreatedIt: false,
                                                       sessionIdGenerator: { SessionId(value: UUID().uuidString) })
            .map { session in
                peerMediator.prepare(myPublicKey: session.publicKey, password: password)
            }

        // TODO(pmvp)  better error handling: if something with session creation or encrypting fails, it means the app is unusable?
        // as we can't pair. crash? big error message? send error logs to cloud?
        switch result {
        case .success(let encryptedPublicKey):
            log.v("Session data created. Sending public key to peer", .cp)
            if !colocatedPairing.write(publicKey: SerializedEncryptedPublicKey(key: encryptedPublicKey)) {
                log.e("Couldn't write my public key to ble", .cp)
            }
        case .failure(let e):
            log.e("Error generating or encrypting my session data: \(e)", .cp)
            uiNotifier.show(.error("Unknown error. Please try again."))
        }
    }
}

// TODO rename deeplink password?
struct ColocatedPeeringPassword {
    let value: String
}

struct ColocatedPeeringPasswordLink {
    let value: URL
    let prefix: String = "\(deeplinkScheme)/pw/"

    init?(value: URL) {
        if value.absoluteString.starts(with: prefix) {
            self.value = value
        } else {
            return nil
        }
    }

    func extractPassword() -> ColocatedPeeringPassword {
        ColocatedPeeringPassword(value: String(value.absoluteString.dropFirst(prefix.count)))
    }
}

struct EncryptedPublicKey {
    let value: String
}

struct SerializedEncryptedPublicKey {
    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(key: EncryptedPublicKey) {
        if let data = key.value.data(using: .utf8) {
            self.init(data: data)
        } else {
            fatalError("Invalid encrypted public key: \(key)")
        }
    }

    func toEncryptedPublicKey() -> EncryptedPublicKey {
        if let string = String(data: data, encoding: .utf8) {
            return EncryptedPublicKey(value: string)
        } else {
            fatalError("Invalid serialized encrypted public key: \(self)")
        }
    }
}

class NoopColocatedSessionService: ColocatedSessionService {
    func startPairingSession() {}

    func generatePassword() -> ColocatedPeeringPassword {
        ColocatedPeeringPassword(value: "123")
    }
}
