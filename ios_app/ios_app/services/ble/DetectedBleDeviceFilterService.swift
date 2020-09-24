import Foundation
import Combine
import CoreBluetooth

/*
 * Broadcasts validated ble peer.
 * Acts as a filter of the "raw" detected ble peer, which has not been validated.
 */
// TODO rename DetectedBlePeerFilterService
protocol DetectedBleDeviceFilterService {
    // TODO rename blePeer
    var device: AnyPublisher<BlePeer, Never> { get }
}

// TODO handling of invalid peer?
// note validated means: they're exposing data in our service and characteristic uuid
// if serv/char uuid are not variable, this can mean anyone using our app
// if they're per-session, it means intentional impostor or some sort of error (?)
// TODO think: should the signed data be the session id?
// if serv/char uuid not variable, this would allow us to identify the session
// but: other people can see if 2 people are meeting
// if serv/char variable, it would still help somewhat but also not ideal privacy
// best priv is variable serv/char + asymmetric encrypted data (peers offer different payload)
// TODO review whetehr this privacy level is needed at this stage

class DetectedBleDeviceFilterServiceImpl: DetectedBleDeviceFilterService {
    let device: AnyPublisher<BlePeer, Never>

    init(deviceDetector: BleDeviceDetector, deviceValidator: BleDeviceValidatorService) {
        device = deviceDetector.discovered.withLatestFrom(deviceValidator.validDevices) { device, validDevices in
            (device, validDevices)
        }
        .compactMap { device, validDevices -> (BleDetectedDevice, BleId)? in
//            log.v("Validating detected device: \(device)", .session)
            if let bleId = validDevices[device.uuid] {
//                log.v("Device is valid", .session)
                return (device, bleId)
            } else {
//                log.v("Device: \(device.uuid) is not valid. Valid devices: \(validDevices)", .session)
                return nil
            }
        }
        .map { detected, bleId in
            detected.toPeer(bleId: bleId)
        }
        .eraseToAnyPublisher()
    }
}

extension BleDetectedDevice {
    func toPeer(bleId: BleId) -> BlePeer {
        let powerLevelMaybe = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue
        let estimatedDistanceMeters = estimateDistance(
            rssi: rssi.doubleValue,
            powerLevelMaybe: powerLevelMaybe
        )
        return BlePeer(deviceUuid: uuid, id: bleId, distance: estimatedDistanceMeters)
    }
}

private func estimateDistance(rssi: Double, powerLevelMaybe: Int?) -> Double {
//    log.d("Estimating distance for rssi: \(rssi), power level: \(String(describing: powerLevelMaybe))")
    return estimatedDistance(
        rssi: rssi,
        powerLevel: powerLevel(powerLevelMaybe: powerLevelMaybe)
    )
}

private func powerLevel(powerLevelMaybe: Int?) -> Double {
    // It seems we have to hardcode this, at least for Android
    // TODO do we have to differentiate between device brands? maybe we need a "handshake" where device
    // communicates it's power level via custom advertisement or gatt?
    return powerLevelMaybe.map { Double($0) } ?? -80 // measured with Android (pixel 3)
}

// The power level is the RSSI at one meter. RSSI is negative, so we make it negative too
// the results seem also not correct, so adjusted
private func powerLevelToUse(_ powerLevel: Double) -> Double {
    switch powerLevel {
        case 12...20:
            return -58
        case 9..<12:
            return -72
        default:
            return -87
    }
}

private func estimatedDistance(rssi: Double, powerLevel: Double) -> Double {
    guard rssi != 0 else {
        return -1
    }
    let pw = powerLevelToUse(powerLevel)
    return pow(10, (pw - rssi) / 20)  // TODO environment factor
}

struct BleDetectedDevice {
    let uuid: UUID
    let advertisementData: [String: Any]
    let rssi: NSNumber
}

class NoopDetectedDeviceFilterService: DetectedBleDeviceFilterService {
    let device = Just(BlePeer(deviceUuid: UUID(), id: BleId(str: "123")!, distance: 10.2)).eraseToAnyPublisher()
}
