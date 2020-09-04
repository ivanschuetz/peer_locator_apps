import SwiftUI
import Combine
import Foundation
import NearbyInteraction // leaky abstraction: TODO map nearby simd_float3 to own type

struct MeetingView: View {
    @ObservedObject private var viewModel: MeetingViewModel
    @Environment(\.colorScheme) var colorScheme

    init(viewModel: MeetingViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        mainView(content: viewModel.mainViewContent)
            .navigationBarTitle(Text("Session"), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                viewModel.onSettingsButtonTap()
            }) { SettingsImage() })
    }

    private func mainView(content: MeetingMainViewContent) -> some View {
        switch content {
        case .enableBle: return AnyView(enableBleView())
        case .connected: return AnyView(connectedView())
        case .unavailable: return AnyView(unavailableView())
        }
    }

    private func enableBleView() -> some View {
        Button("Please enable bluetooth to connect with peer") {
            viewModel.requestEnableBle()
        }
    }

    private func connectedView() -> some View {
        VStack(alignment: .center) {
            Triangle()
                .fill(Color.black)
                .frame(width: 60, height: 60)
                .padding(.bottom, 30)
                .rotationEffect(viewModel.directionAngle)
            Text(viewModel.distance)
                .font(.system(size: 50, weight: .heavy))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .padding(.bottom, 50)
            Button("Delete session") {
                viewModel.deleteSession()
            }
        }
    }

    private func unavailableView() -> some View {
        // TODO maybe add question mark and explain: out of range / device off / ble off
        Text("Peer is not in range")
    }
}

struct MeetingView_Previews: PreviewProvider {
    static var previews: some View {
        let bleManager = BleManagerImpl(peripheral: BlePeripheralNoop(), central: BleCentralFixedDistance())
        let peerService = PeerServiceImpl(nearby: NearbyNoop(), bleManager: bleManager, bleIdService: BleIdServiceNoop())
        let sessionService = NoopCurrentSessionService()
        MeetingView(viewModel: MeetingViewModel(peerService: peerService, sessionService: sessionService,
                                                settingsShower: NoopSettingsShower(),
                                                bleEnabledService: NoopBleEnabledService()))
    }
}

class BleCentralFixedDistance: NSObject, BleCentral {
    let discovered = Just(BleParticipant(id: BleId(str: "123")!,
                                         distance: 10.2)).eraseToAnyPublisher()
    let status = Just(BleState.poweredOn).eraseToAnyPublisher()
    let writtenMyId = PassthroughSubject<BleId, Never>()
    func requestStart() {}
    func stop() {}
    func write(nearbyToken: SerializedSignedNearbyToken) -> Bool { true }
}

class BleIdServiceNoop: BleIdService {
    func id() -> BleId? {
        nil
    }

    func validate(bleId: BleId) -> Bool {
        false
    }
}

class NearbyNoop: Nearby {
    var sessionState = Just(SessionState.notInit).eraseToAnyPublisher()
    var discovered: AnyPublisher<NearbyObj, Never> =
        Just(NearbyObj(name: "foo", dist: 1.2, dir: simd_float3(1, 1, 0))).eraseToAnyPublisher()

    func token() -> NearbyToken? { nil }
    func start(peerToken token: NearbyToken) {}
}
