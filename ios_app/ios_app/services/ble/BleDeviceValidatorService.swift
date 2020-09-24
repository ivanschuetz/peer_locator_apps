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
    if validationResults.keys.contains(blePeer.deviceUuid) {
        return validationResults
    }

    var mutDict = validationResults
    let isValid = idService.validate(bleId: blePeer.id)
    log.i("Validated device: \(blePeer.id), valid?: \(isValid)", .peer, .ble)
    mutDict[blePeer.deviceUuid] = DetectedDeviceValidationResult(bleId: blePeer.id, isValid: isValid)
    return mutDict
}

class NoopBleValidatorService: BleDeviceValidatorService {
    let validDevices: AnyPublisher<[UUID : BleId], Never> = Just([:]).eraseToAnyPublisher()
}
