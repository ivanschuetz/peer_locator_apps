import SwiftUI
import Combine
import Foundation
import NearbyInteraction // leaky abstraction: TODO map nearby simd_float3 to own type

struct MeetingView: View {
    @ObservedObject private var viewModel: MeetingViewModel
    @Environment(\.colorScheme) var colorScheme

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.meeting()
    }

    var body: some View {
        mainView(content: viewModel.mainViewContent)
            .navigationBarTitle(Text("Session"), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: { [weak viewModel] in
                viewModel?.onSettingsButtonTap()
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
        VStack {
            Button("Please enable bluetooth to connect with peer") {
                viewModel.requestEnableBle()
            }
            .padding(.bottom, 50)
            ActionDeleteButton("Delete session") {
                viewModel.deleteSession()
            }
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
            ActionDeleteButton("Delete session") {
                viewModel.deleteSession()
            }
        }
    }

    private func unavailableView() -> some View {
        VStack {
            Text("Peer not detected")
                .bold()
                .multilineTextAlignment(.center)
                .padding(.bottom, 30)
            Text("Your peer is not in range or their device isn't available")
                .multilineTextAlignment(.center)
                .padding(.bottom, 50)
            ActionDeleteButton("Delete session") {
                viewModel.deleteSession()
            }
        }
    }
}

struct MeetingView_Previews: PreviewProvider {
    static var previews: some View {
        MeetingView(viewModelProvider: DummyViewModelProvider())
    }
}
