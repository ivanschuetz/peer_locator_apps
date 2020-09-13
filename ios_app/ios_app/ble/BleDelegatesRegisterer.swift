import CoreBluetooth
import Combine

class BleDelegatesRegisterer {

    init(blePeripheral: BlePeripheral, idService: BleIdService) {
        let validation = BleMeetingValidation(idService: idService)
        let nearbyPairing = BleNearbyPairing()
        let colocatedPairing = BleColocatedPairing()

        blePeripheral.register(delegates: [validation, nearbyPairing, colocatedPairing])
    }
}
