import CoreBluetooth
import Combine

protocol BleCentralDelegate {
    func onConnectPeripheral(_ peripheral: CBPeripheral)
    func onDidFailToConnectToPeripheral(_ peripheral: CBPeripheral)
    func onDisconnectPeripheral(_ peripheral: CBPeripheral)

    func onDiscoverPeripheral(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber)

    func onReadCharacteristic(_ characteristic: CBCharacteristic, peripheral: CBPeripheral, error: Error?) -> Bool

    func onWriteCharacteristicAck(_ characteristic: CBCharacteristic, peripheral: CBPeripheral, error: Error?)

    func onDiscoverCaracteristics(_ characteristics: [CBCharacteristic], peripheral: CBPeripheral, error: Error?) -> Bool
}
