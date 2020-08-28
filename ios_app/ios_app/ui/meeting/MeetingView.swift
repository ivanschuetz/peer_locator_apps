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
}

struct MeetingView_Previews: PreviewProvider {
    static var previews: some View {
        let bleManager = BleManagerImpl(peripheral: BlePeripheralNoop(), central: BleCentralFixedDistance())
        let peerService = PeerServiceImpl(nearby: NearbyNoop(), bleManager: bleManager, bleIdService: BleIdServiceNoop())
        let sessionService = NoopCurrentSessionService()
        let uiNotifier = NoopUINotifier()
        MeetingView(viewModel: MeetingViewModel(peerService: peerService, sessionService: sessionService))
    }
}

class BleCentralFixedDistance: NSObject, BleCentral {
    let discovered = Just(BleParticipant(id: BleId(str: "123")!,
                                         distance: 10.2)).eraseToAnyPublisher()
    let statusMsg = PassthroughSubject<String, Never>()
    let writtenMyId = PassthroughSubject<BleId, Never>()
    func requestStart() {}
    func stop() {}
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
    var discovered: AnyPublisher<NearbyObj, Never> =
        Just(NearbyObj(name: "foo", dist: 1.2, dir: simd_float3(1, 1, 0))).eraseToAnyPublisher()
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}
