import SwiftUI
import UIKit
import Combine

struct HomeView: View {

    @ObservedObject private var viewModel: HomeViewModel
    @ObservedObject private var sessionViewModel: SessionViewModel

    init(viewModel: HomeViewModel, sessionViewModel: SessionViewModel) {
        self.viewModel = viewModel
        self.sessionViewModel = sessionViewModel
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
                SessionView(viewModel: sessionViewModel)
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(viewModel: HomeViewModel(central: BleCentralNoop(),
                                          peripheral: BlePeripheralNoop(),
                                          radarService: RadarUIServiceNoop(),
                                          notificationPermission: NotificationPermissionImpl()),
                 sessionViewModel: SessionViewModel(sessionApi: NoopSessionApi()))
    }
}
