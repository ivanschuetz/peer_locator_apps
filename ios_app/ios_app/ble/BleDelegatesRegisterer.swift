import CoreBluetooth
import Combine

class BleDelegatesRegisterer {

    init(blePeripheral: BlePeripheral, idService: BleIdService) {
        let validation = BleValidationDataReaderImpl(idService: idService)
        let nearbyPairing = BleNearbyPairing(bleValidator: NoopBleValidatorService())
        let colocatedPairing = BleColocatedPairingImpl()

        blePeripheral.register(delegates: [validation, nearbyPairing, colocatedPairing])
    }
}
