import Foundation
import Combine
import CoreBluetooth

/**
 * Performs the validation on the signed data retrieved from peer.
 */
protocol BleDeviceValidatorService {
    func filterIsValid(peripheral: AnyPublisher<CBPeripheral, Never>) -> AnyPublisher<CBPeripheral, Never>
    
    func filterIsValid(device: AnyPublisher<BleDetectedDevice, Never>) ->
        AnyPublisher<(BleDetectedDevice, BleId), Never>
}

class BleDeviceValidatorServiceImpl: BleDeviceValidatorService {
    private let validationResults: AnyPublisher<[UUID: DetectedDeviceValidationResult], Never>
    let validDevices: AnyPublisher<[UUID: BleId], Never>

    init(validationDataReader: BleValidationDataReader, idService: BleIdService) {
        validationResults = validationDataReader.read
            .scan([UUID: DetectedDeviceValidationResult](), { dict, peer in
                updateValidPeers(validationResults: dict, blePeer: peer, idService: idService)
            })
            .eraseToAnyPublisher()

        validDevices = validationResults.map { dict in
            dict
                .filter({ _, value in value.isValid })
                .mapValues { $0.bleId }
        }
        .eraseToAnyPublisher()
    }

    func isValid(deviceUuid: AnyPublisher<UUID, Never>) -> AnyPublisher<Bool, Never> {
        deviceUuid.withLatestFrom(validDevices) { uuid, validDevices in
            validDevices.keys.contains(uuid)
        }
        .eraseToAnyPublisher()
    }

    func filterIsValid(peripheral: AnyPublisher<CBPeripheral, Never>) -> AnyPublisher<CBPeripheral, Never> {
        peripheral.withLatestFrom(validDevices) { peripheral, validDevices in
            (peripheral, validDevices)
        }
        .compactMap { peripheral, validDevices in
            if validDevices.keys.contains(peripheral.identifier) {
                return peripheral
            } else {
                return nil
            }
        }
        .eraseToAnyPublisher()
    }

    func filterIsValid(device: AnyPublisher<BleDetectedDevice, Never>) ->
        AnyPublisher<(BleDetectedDevice, BleId), Never> {
        device.withLatestFrom(validDevices) { device, validDevices in
            (device, validDevices)
        }
        .compactMap { device, validDevices in
            if let bleId = validDevices[device.uuid] {
                return (device, bleId)
            } else {
                return nil
            }
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
    func filterIsValid(peripheral: AnyPublisher<CBPeripheral, Never>) -> AnyPublisher<CBPeripheral, Never> {
        Empty().eraseToAnyPublisher()
    }

    func filterIsValid(device: AnyPublisher<BleDetectedDevice, Never>)
        -> AnyPublisher<(BleDetectedDevice, BleId), Never> {
        Empty().eraseToAnyPublisher()
    }
}
