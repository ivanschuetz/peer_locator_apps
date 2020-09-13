import CoreBluetooth
import Combine

enum BlePeripheralEvent {
    case stateChanged(BleState)
    case write(uuid: CBUUID, data: Data)
    case read(uuid: CBUUID, request: CBATTRequest, peripheral: CBPeripheralManager)
}

protocol BlePeripheralDelegate {
    var characteristic: CBMutableCharacteristic { get }
    func handleEvent(_ event: BlePeripheralEvent) -> Bool
}

protocol BlePeripheralDelegateWriteOnly: BlePeripheralDelegate {
    func handleEvent(_ event: BlePeripheralEvent) -> Bool
    func handleWrite(data: Data)
}

extension BlePeripheralDelegateWriteOnly {
    func handleEvent(_ event: BlePeripheralEvent) -> Bool {
        switch event {
        case .write(let uuid, let data):
            if uuid == characteristic.uuid {
                handleWrite(data: data)
                return true
            } else {
                return false
            }
        default: return false
        }
    }
}

protocol BlePeripheralDelegateReadOnly: BlePeripheralDelegate {
    func handleEvent(_ event: BlePeripheralEvent) -> Bool
    func handleRead(uuid: CBUUID, request: CBATTRequest, peripheral: CBPeripheralManager)
}

extension BlePeripheralDelegateReadOnly {
    func handleEvent(_ event: BlePeripheralEvent) -> Bool {
        switch event {
        case .read(let uuid, let request, let peripheral):
            if uuid == characteristic.uuid {
                handleRead(uuid: uuid, request: request, peripheral: peripheral)
                return true
            } else {
                return false
            }
        default: return false
        }
    }
}
