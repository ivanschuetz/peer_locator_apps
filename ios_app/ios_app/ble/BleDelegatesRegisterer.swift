import CoreBluetooth
import Combine

class BleDelegatesRegisterer {

    init(blePeripheral: BlePeripheral, bleCentral: BleCentral, nearbyPairing: NearbyPairing,
         bleValidation: BleValidation, bleDeviceDetector: BleDeviceDetector,
         idService: BleIdService, colocatedPairing: BleColocatedPairing) {
        blePeripheral.register(delegates: [bleValidation, nearbyPairing, colocatedPairing])
        bleCentral.register(delegates: [bleDeviceDetector, bleValidation, nearbyPairing, colocatedPairing])
    }
}
