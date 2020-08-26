import SwiftUI
import Combine

struct HomeView: View {
    @ObservedObject private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Text("Home")
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(viewModel: HomeViewModel(central: BleCentralNoop(),
                                          peripheral: BlePeripheralNoop(),
                                          radarService: RadarUIServiceNoop(),
                                          notificationPermission: NotificationPermissionImpl()))
    }
}
