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
                var mutDict = dict
                if idService.validate(bleId: peer.id) {
                    log.i("Validated device: \(peer.id)", .peer, .ble)
                    mutDict[peer.deviceUuid] = peer.id
                } else {
                    // Invalid device means only that the peer is unknown.
                    // (i.e. we don't have the public key to validate their signature)
                    // usually this will be because it's not our peer (but someone else using the app/service uuid)
                    // of course it's also possible that it's our peer and there's a programming error.
                    log.v("Device didn't pass validation: \(peer.id)", .peer, .ble)
                }
                return mutDict
            })
            .eraseToAnyPublisher()
    }
}
