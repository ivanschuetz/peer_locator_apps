import SwiftUI
import Combine

struct MeetingView: View {
    @ObservedObject private var viewModel: MeetingViewModel

    init(viewModel: MeetingViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(alignment: .center) {
            Text(viewModel.distance)
                .font(.system(size: 50, weight: .heavy))
                .foregroundColor(.white)
        }
    }
}

struct MeetingView_Previews: PreviewProvider {
    static var previews: some View {
        let bleManager = BleManagerImpl(peripheral: BlePeripheralNoop(), central: BleCentralFixedDistance())
        MeetingView(viewModel: MeetingViewModel(bleManager: bleManager))
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
