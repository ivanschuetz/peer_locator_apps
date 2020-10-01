import Foundation
import Combine
import CoreBluetooth

/**
 * Exposes observable with valid (signature verification) device uuids.
 */
protocol BleDeviceValidatorService {
    var validDevices: AnyPublisher<[UUID: BleId], Never> { get }
}

class BleDeviceValidatorServiceImpl: BleDeviceValidatorService {
    // TODO check out of memory, since we store now all detected devices. Max capacity dictionary?
    // Note also scan operator below.
    private let validationResults: AnyPublisher<[UUID: DetectedDeviceValidationResult], Never>

    let validDevices: AnyPublisher<[UUID: BleId], Never>

    private var cancellables: Set<AnyCancellable> = []

    init(bleValidation: BleValidation, idService: BleIdService) {
        validationResults = bleValidation.read
            .scan([UUID: DetectedDeviceValidationResult](), { dict, peer in
                updateValidPeers(validationResults: dict, blePeer: peer, idService: idService)
            })
            .eraseToAnyPublisher()

        validDevices = validationResults
            .map { dict in
                dict
                    .filter({ _, value in value.isValid })
                    .mapValues { $0.bleId }
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    func isValid(deviceUuid: AnyPublisher<UUID, Never>) -> AnyPublisher<Bool, Never> {
        log.v("Validating device: \(deviceUuid)", .session)
        return deviceUuid.withLatestFrom(validDevices) { uuid, validDevices in
            let res = validDevices.keys.contains(uuid)
            log.d("Device: \(deviceUuid) valid?: \(res)", .session)
            return res
        }
        .eraseToAnyPublisher()
    }
}

private struct DetectedDeviceValidationResult {
    let bleId: BleId
    let isValid: Bool
}

/**
 * Adds ble peer's validation result to dictionary.
 */
private func updateValidPeers(validationResults: [UUID: DetectedDeviceValidationResult], blePeer: BlePeer,
                              idService: BleIdService) -> [UUID: DetectedDeviceValidationResult] {

    log.v("Updating valid peers with: \(blePeer)", .ble)

    // if it was already validated, don't validate again (validation is expensive).
    // when we implement periodic validation probably we have to pass a flag to force validation.
    // clearing the dictionary would probably not be good, as it would interrupt the distance measurements.

    // TODO commenting for now, as we implemented periodic validation, and of course this will cache
    // invalid state forever. We need to improve the mechanism.
    // Note that it's not overly critical pre-mvp, as validation happens only each 5 secs and most people testing
    // will not have a lot of devices with the app installed around. It also doesn't seem critical for release.
    // it should be improved when we believe enough people are using the app.
//    if validationResults.keys.contains(blePeer.deviceUuid) {
//        log.d("Device was already validated. Returning cached result: \(validationResults[blePeer.deviceUuid])", .session)
//        return validationResults
//    }

    var mutDict = validationResults
    let isValid = idService.validate(bleId: blePeer.id)
    log.i("Validated device: \(blePeer.id), valid?: \(isValid)", .peer, .ble)
    mutDict[blePeer.deviceUuid] = DetectedDeviceValidationResult(bleId: blePeer.id, isValid: isValid)
    return mutDict
}

class NoopBleValidatorService: BleDeviceValidatorService {
    let validDevices: AnyPublisher<[UUID : BleId], Never> = Just([:]).eraseToAnyPublisher()
}
