import CoreBluetooth
import Combine

class BleDelegatesRegisterer {

    init(blePeripheral: BlePeripheral, idService: BleIdService) {
        let validation = BleValidationDataReader(idService: idService)
        let nearbyPairing = BleNearbyPairing(bleValidator: NoopBleValidatorService())
        let colocatedPairing = BleColocatedPairing()

        blePeripheral.register(delegates: [validation, nearbyPairing, colocatedPairing])
    }
}
