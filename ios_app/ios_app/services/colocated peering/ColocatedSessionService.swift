import Foundation
import Combine

protocol ColocatedSessionService {
//    func ses
    func startPairingSession()
    func generatePassword() -> ColocatedPeeringPassword
}

class ColocatedSessionServiceImpl: ColocatedSessionService {
    private let bleCentral: BleCentral
    private let keyChain: KeyChain
    private let crypto: Crypto
    private let uiNotifier: UINotifier
    private let sessionService: CurrentSessionService
    private let bleManager: BleManager

    private var passwordCancellable: Cancellable?
    private var peripheralReceivedKeyCancellable: Cancellable?

    private let shouldReplyWithMyKey = CurrentValueSubject<Bool, Never>(true)

    init(bleCentral: BleCentral, peerKeyReceiver: ColocatedPublicKeyReceiver, keyChain: KeyChain,
         passwordProvider: ColocatedPasswordProvider, passwordService: ColocatedPairingPasswordService,
         crypto: Crypto, uiNotifier: UINotifier, sessionService: CurrentSessionService, bleManager: BleManager) {
        self.bleCentral = bleCentral
        self.keyChain = keyChain
        self.crypto = crypto
        self.uiNotifier = uiNotifier
        self.sessionService = sessionService
        self.bleManager = bleManager

        // TODO error handling during close pairing:
        // - received corrupted data
        // - timeout reading
        // -> investigate if ble handles this for us somehow
        // -> possible: retry 3 times, if fails, offer user to retry or re-start the pairing (with a different pw)
        // generally, review this whole file. It's just a happy path poc.

        peripheralReceivedKeyCancellable = peerKeyReceiver.publicKey
            .combineLatest(shouldReplyWithMyKey.eraseToAnyPublisher())
            .sink { [weak self] key, shouldReply in
                if let password = passwordProvider.password() {
                    self?.handleReceivedKey(key: key, password: password, shouldReply: shouldReply)
                } else {
                    let msg = "Invalid state? peer sent us their public key but we haven't stored a pw."
                    log.e(msg, .cp)
                    uiNotifier.show(.success(msg))
                    // TODO better handling
                }
        }

        passwordCancellable = passwordService.password
            .sink { [weak self] in
                self?.handleReceivedPassword($0)
            }
    }

    func startPairingSession() {
        log.i("Starting colocated pairing session", .cp)
        bleManager.start()
    }

    func generatePassword() -> ColocatedPeeringPassword {
        // TODO this side effect is quick and dirty, probably better way to reset this?
        shouldReplyWithMyKey.send(true)

        // TODO random, qr code
        return ColocatedPeeringPassword(value: "123")
    }

    private func handleReceivedKey(key: SerializedEncryptedPublicKey, password: ColocatedPeeringPassword,
                                   shouldReply: Bool) {

        let encryptedKey = key.toEncryptedPublicKey()

        guard let publicKeyValue = crypto.decrypt(str: encryptedKey.value, key: password.value) else {
            log.e("Received an invalid peer public key: \(encryptedKey). Exit.", .cp)
            return
        }

        // TODO "transactionally". Currently we store first the participants, if success then our session data...
        // we should store them ideally together. Prob after refactor that merges session data and participants.
        switch keyChain.putEncodable(key: .participants, value: Participants(participants: [
            PublicKey(value: publicKeyValue)
        ])) {
        case .success:
            if shouldReply {
                log.d("Received data from peer. Will send back my data", .cp)
                initializeMySessionDataAndSendPublicKey(password: password)
            }

            log.d("Received and stored peer's public key. Validating peer (meeting).", .cp)
            // more quick "happy path"... directly after receiving peer's key, validate TODO review
            _ = bleCentral.validatePeer()

            // TODO we probably should ACK having peer's keys (like we do with the backend)
            // otherwise one participant may show success while the other doesn't have the peer key, which is critical
            // (for colocated mostly not, as they'd notice immediately, but still, at least for correctness)
            // ack like everything else would probably need a retry too
            // for now we will mark here directly the session as ready

            // Note that this, by setting the current session controls the root navigation
            let mySessionData: Result<MySessionData?, ServicesError> = keyChain.getDecodable(key: .mySessionData)
            let sharedSessionData: Result<SharedSessionData?, ServicesError> = mySessionData.map({ mySessionData in
                mySessionData.map {
                    SharedSessionData(id: $0.sessionId, isReady: .yes, createdByMe: $0.createdByMe)
                }
            })
            sessionService.setSessionResult(sharedSessionData)

        case .failure(let e):
            log.e("Couldn't save peer key: \(e)", .cp)
        }
    }

    private func handleReceivedPassword(_ password: ColocatedPeeringPassword) {
        // The one receiving the password deeplink sends the public key immediately, so when we receive
        // peer's public key we don't send it again.
        shouldReplyWithMyKey.send(false)
        // TODO probably should be set to false only if initializeMySessionDataAndSendPublicKey succeeds,
        // check flow
        log.d("Received password from peer. Will send my data.", .cp)
        initializeMySessionDataAndSendPublicKey(password: password)
    }

    private func initializeMySessionDataAndSendPublicKey(password: ColocatedPeeringPassword) {
        let res = createStoreSessionDataAndEncryptPublicKey(
            isCreate: false, crypto: crypto, keyChain: keyChain, pw: password,
            sessionIdGenerator: { SessionId(value: UUID().uuidString) })
        handleSessionCreationResult(result: res, bleCentral: bleCentral, uiNotifier: uiNotifier)
    }
}


// TODO better error handling: if something with session creation or encrypting fails, it means the app is unusable?
// as we can't pair. crash? big error message? send error logs to cloud?
private func handleSessionCreationResult(result: Result<EncryptedPublicKey, ServicesError>, bleCentral: BleCentral,
                                         uiNotifier: UINotifier) {
    switch result {
    case .success(let encryptedPublicKey):
        log.v("Session data created. Sending public key to peer", .cp)
        if !bleCentral.write(publicKey: SerializedEncryptedPublicKey(key: encryptedPublicKey)) {
            log.e("Couldn't write my public key to ble", .cp)
        }
    case .failure(let e):
        let msg = "Error generating or encrypting my session data: \(e)"
        log.e(msg, .cp)
        uiNotifier.show(.error(msg))
    }
}

private func createStoreSessionDataAndEncryptPublicKey(
    isCreate: Bool, crypto: Crypto, keyChain: KeyChain, pw: ColocatedPeeringPassword,
    sessionIdGenerator: () -> SessionId
) -> Result<EncryptedPublicKey, ServicesError> {

    let res = createAndStoreSessionData(isCreate: isCreate, crypto: crypto, keyChain: keyChain,
                                        sessionIdGenerator: sessionIdGenerator)
    return res.map { sessionData in
        EncryptedPublicKey(value: crypto.encrypt(str: sessionData.publicKey.value, key: pw.value))
    }
}


// TODO refactor with same name function in SessionServiceImpl
private func createAndStoreSessionData(isCreate: Bool, crypto: Crypto, keyChain: KeyChain,
                                       sessionIdGenerator: () -> SessionId) -> Result<MySessionData, ServicesError> {
    let keyPair = crypto.createKeyPair()
    log.d("Created key pair: \(keyPair)", .session)
    let sessionId = sessionIdGenerator()
    let sessionData = MySessionData(
        sessionId: sessionId,
        privateKey: keyPair.private_key,
        publicKey: keyPair.public_key,
        participantId: keyPair.public_key.toParticipantId(crypto: crypto),
        createdByMe: isCreate
    )
    let saveRes = keyChain.putEncodable(key: .mySessionData, value: sessionData)
    switch saveRes {
    case .success:
        return .success(sessionData)
    case .failure(let e):
        return .failure(.general("Couldn't save session data in keychain: \(e)"))
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
