import SwiftUI
import Combine

struct MeetingView: View {
    @ObservedObject private var viewModel: MeetingViewModel

    init(viewModel: MeetingViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        GeometryReader { geometry in
            VStack {
                RadarView(viewModel: viewModel).frame(width: 300, height: 300)
                Text("Ble Status:")
                Text(viewModel.labelValue)
                Divider()
                Text("My id:")
                Text(viewModel.myId)
                Divider()
                Text("Discovered ids:")
                List(viewModel.detectedDevices) { bleId in
                    Text(bleId.bleId.str())
                }
            }
        }
    }
}

struct MeetingView_Previews: PreviewProvider {
    static var previews: some View {
        MeetingView(viewModel: MeetingViewModel(central: BleCentralNoop(),
                                                peripheral: BlePeripheralNoop(),
                                                radarService: RadarUIServiceNoop(),
                                                notificationPermission: NotificationPermissionImpl()))
    }
}
