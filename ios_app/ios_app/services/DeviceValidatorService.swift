import Foundation
import Combine

protocol DeviceValidatorService {
    var validDevices: AnyPublisher<[UUID: BleId], Never> { get }
}

class DeviceValidatorServiceImpl: DeviceValidatorService {
    let validDevices: AnyPublisher<[UUID: BleId], Never>

    init(meetingValidation: BleMeetingValidation, idService: BleIdService) {

        validDevices = meetingValidation.discovered
            .scan([UUID: BleId](), { dict, participant in
                var mutDict = dict
                if idService.validate(bleId: participant.id) {
                    log.i("Validated device: \(participant.id)", .peer, .ble)
                    mutDict[participant.deviceUuid] = participant.id
                } else {
                    // Invalid device means only that the peer is unknown.
                    // (i.e. we don't have the public key to validate their signature)
                    // usually this will be because it's not our peer (but someone else using the app/service uuid)
                    // of course it's also possible that it's our peer and there's a programming error.
                    log.v("Device didn't pass validation: \(participant.id)", .peer, .ble)
                }
                return mutDict
            })
            .eraseToAnyPublisher()
    }
}
