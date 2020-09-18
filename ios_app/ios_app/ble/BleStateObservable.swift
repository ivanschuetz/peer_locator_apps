import Foundation
import Combine

protocol BleStateObservable {
    var central: AnyPublisher<BleState, Never> { get }
    var peripheral: AnyPublisher<BleState, Never> { get }

    var bleEnabled: AnyPublisher<Bool, Never> { get }

    var allReady: AnyPublisher<Bool, Never> { get }
}

class BleStateObservableImpl: BleStateObservable {
    let central: AnyPublisher<BleState, Never>
    let peripheral: AnyPublisher<BleState, Never>

    let bleEnabled: AnyPublisher<Bool, Never>

    let allReady: AnyPublisher<Bool, Never>

    init(bleCentral: BleCentral, blePeripheral: BlePeripheral) {
        central = bleCentral.status
        peripheral = blePeripheral.status

        // iOS doesn't offer anything to check directly if ble is enabled, seems to be done always by
        // checking the central's state (probably peripheral would work too, peripheral is just usually not used)
        // Note that we keep this separate to "allReady" as this is the minumum to check whether ble is enabled
        // while "allReady" may be false due to more reasons (e.g. unexpected error initializing the peripheral)
        bleEnabled = central
            .map { $0 == .poweredOn }
            .prepend(false)
            .eraseToAnyPublisher()

        allReady = central.combineLatest(peripheral)
            .map { centralState, peripheralState in
                centralState == .poweredOn && peripheralState == .poweredOn
            }
            .prepend(false)
            .handleEvents(receiveOutput: { ready in
                log.d("Ble components ready: \(ready)", .ble)
            })
            .eraseToAnyPublisher()
    }
}

class NoopBleStateObservable: BleStateObservable {
    let central: AnyPublisher<BleState, Never> = Just(.poweredOn).eraseToAnyPublisher()
    let peripheral: AnyPublisher<BleState, Never> = Just(.poweredOn).eraseToAnyPublisher()
    let bleEnabled: AnyPublisher<Bool, Never> = Just(true).eraseToAnyPublisher()
    let allReady: AnyPublisher<Bool, Never> = Just(true).eraseToAnyPublisher()
}
