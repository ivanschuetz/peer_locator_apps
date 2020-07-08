import SwiftUI
import UIKit
import Combine

struct HomeView: View {

    @ObservedObject private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack {
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

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(viewModel: HomeViewModel(central: BleCentralNoop(), peripheral: BlePeripheralNoop()))
    }
}
