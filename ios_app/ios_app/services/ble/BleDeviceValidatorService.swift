import Foundation
import Combine

/**
 * Performs the validation on the signed data retrieved from peer.
 * Exposes valid devices in a dictionary, with the ble device UUID as key.
 */
protocol BleDeviceValidatorService {
    var validDevices: AnyPublisher<[UUID: BleId], Never> { get }
}

class BleDeviceValidatorServiceImpl: BleDeviceValidatorService {
    let validDevices: AnyPublisher<[UUID: BleId], Never>

    init(validationDataReader: BleValidationDataReader, idService: BleIdService) {
        validDevices = validationDataReader.read
            .scan([UUID: BleId](), { dict, peer in
                updateValidPeers(validPeers: dict, blePeer: peer, idService: idService)
            })
            .eraseToAnyPublisher()
    }
}

/**
 * Adds ble peer to dictionary of valid peers if valid.
 */
private func updateValidPeers(validPeers: [UUID: BleId], blePeer: BlePeer, idService: BleIdService) -> [UUID: BleId] {
    // if it was already validated, don't validate again (validation is expensive).
    // when we implement periodic validation probably we have to pass a flag to force validation.
    // clearing the dictionary would probably not be good, as it would interrupt the distance measurements.
    if validPeers.keys.contains(blePeer.deviceUuid) {
        return validPeers
    }

    var mutDict = validPeers
    if idService.validate(bleId: blePeer.id) {
        log.i("Validated device: \(blePeer.id)", .peer, .ble)
        mutDict[blePeer.deviceUuid] = blePeer.id
    } else {
        // Invalid device means only that the peer is unknown.
        // (i.e. we don't have the public key to validate their signature)
        // usually this will be because it's not our peer (but someone else using the app/service uuid)
        // of course it's also possible that it's our peer and there's a programming error.
        log.v("Device didn't pass validation: \(blePeer.id)", .peer, .ble)
    }
    return mutDict
}
