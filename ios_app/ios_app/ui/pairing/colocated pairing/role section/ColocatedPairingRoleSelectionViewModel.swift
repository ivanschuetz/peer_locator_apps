import Foundation
import SwiftUI
import Combine
import CoreBluetooth

enum ColocatedPairingRoleDestination {
    case create, join, none
}

class ColocatedPairingRoleSelectionViewModel: ObservableObject {
    @Published var destination: ColocatedPairingRoleDestination = .none
    @Published var navigationActive: Bool = false

    private let bleState: BleStateObservable
    private let sessionService: ColocatedSessionService
    private let bleActivator: BleActivator
    private let uiNotifier: UINotifier

    private let createSessionSubject: PassthroughSubject = PassthroughSubject<(), Never>()
    private let joinSessionSubject: PassthroughSubject = PassthroughSubject<(), Never>()

    private var createSessionCancellable: AnyCancellable?
    private var joinSessionCancellable: AnyCancellable?

    private var pendingDestination = PassthroughSubject<ColocatedPairingRoleDestination?, Never>()

    private var navigateToCancellable: AnyCancellable?

    init(sessionService: ColocatedSessionService, bleState: BleStateObservable, bleActivator: BleActivator,
         uiNotifier: UINotifier) {
        self.sessionService = sessionService
        self.bleState = bleState
        self.uiNotifier = uiNotifier
        self.bleActivator = bleActivator

        createSessionCancellable = createSessionSubject.withLatestFrom(bleState.allReady.removeDuplicates())
            .sink { [weak self] bleReady in
                self?.navigateIfBluettothEnabled(destination: .create, bleReady: bleReady)
            }

        joinSessionCancellable = joinSessionSubject.flatMap { _ in bleState.allReady.removeDuplicates() }
            .sink { [weak self] bleReady in
                self?.navigateIfBluettothEnabled(destination: .join, bleReady: bleReady)
            }

        // TODO critical: this mostly doesn't work the first time after installing the app (either with ble disabled or enabled)
        // The last message here is "Ble not ready (... destination: .create ...) Doing nothing." and never executes sink,
        // though we get "Ble components ready: true" from BleStateObservable shortly after.
        // it usually works when stepping through the observers with the debugger.
        // so timing? but where? inserting asyncAfter 1 sec in various places didn't help
        // it also doesn't work if we use pendingDestination.withLatestFrom(bleState.allReady)
        // Critical because it silently prevents the user from navigating forward
        navigateToCancellable = bleState.allReady.combineLatest(pendingDestination)
            .compactMap { ready, pendingDestination in
                if ready {
                    if let dest = pendingDestination {
                        return dest
                    } else {
                        log.v("Ble ready. No pending destination. doing nothing.", .ui)
                        return nil
                    }
                } else {
                    log.v("Ble not ready. (Pending destination: \(String(describing: pendingDestination))). " +
                        "Doing nothing.", .ui)
                    return nil
                }
            }
            .sink { [weak self] (dest: ColocatedPairingRoleDestination) in
                log.d("Clearing pending destination", .ui)
                self?.pendingDestination.send(nil)

                self?.navigate(to: dest)
            }
    }

    /**
     * We need ble for pairing, and we don't want to force user to enable always ble, so we do it here.
     * 1) we show dialog to enable it if it's disabled
     * 2) since 1) is managed internally by iOS (we can't check if it's disabled or wait for the dialog result)
     * we immediately show an error notification if the central/peripheral are not ready.
     * This way, if it's not ready for reasons other than ble being disabled (which are unknown to me at the moment),
     * the user sees something.
     * Note that the app always tries to connect the central/peripheral when coming to fg,
     * so it will do this after the user enables ble in the settings.
     */
    private func navigateIfBluettothEnabled(destination: ColocatedPairingRoleDestination, bleReady: Bool) {
        if bleReady {
            navigate(to: destination)
        } else {
            log.d("Bluetooth is not ready, activating...", .ui, .ble)
            pendingDestination.send(destination)
            bleActivator.activate()
        }
    }

    func onCreateSessionTap() {
        createSessionSubject.send(())
    }

    func onJoinSessionTap() {
        joinSessionSubject.send(())
    }

    private func navigate(to: ColocatedPairingRoleDestination) {
        log.d("Navigating to: \(to)", .ui)
        destination = to
        navigationActive = true
    }
}
