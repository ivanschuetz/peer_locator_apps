import SwiftUI
import Combine
import Foundation

struct MeetingView: View {
    @ObservedObject private var viewModel: MeetingViewModel
    private var viewModelProvider: ViewModelProvider

    @State private var showConfirmDeleteAlert = false

    @Environment(\.colorScheme) var colorScheme

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.meeting()
        self.viewModelProvider = viewModelProvider
    }

    var body: some View {
        mainView(content: viewModel.mainViewContent)
            .defaultOuterHPadding()
            .navigationBarTitle(Text("Session"), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: { [weak viewModel] in
                viewModel?.onSettingsButtonTap()
            }) { SettingsImage() })
        .sheet(isPresented: $viewModel.showSettingsModal) {
            SettingsView(viewModelProvider: viewModelProvider)
        }
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
            .multilineTextAlignment(.center)
            .padding(.bottom, 50)
            ActionDeleteButton("Delete session") {
                viewModel.deleteSession()
            }
        }
        .defaultOuterHPadding()
    }

    private func connectedView() -> some View {
        VStack(alignment: .center) {
            if viewModel.isAccurate {
                Triangle()
                    .fill(Color.icon)
                    .frame(width: 60, height: 60)
                    .padding(.bottom, 30)
                    .rotationEffect(viewModel.directionAngle)
                }
            HStack {
                if viewModel.isAccurate {
                    Text("~")
                        .font(.system(size: 50, weight: .heavy))
                        .foregroundColor(colorScheme == .dark ? .gray : .gray)
                }
                Text(viewModel.distance)
                    .font(.system(size: 50, weight: .heavy))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            .padding(.bottom, 50)
            ActionDeleteButton("Delete session") {
                showConfirmDeleteAlert = true
            }
        }
        .alert(isPresented: $showConfirmDeleteAlert) {
            Alert(title: Text("Delete session"),
                  message: Text("Are you sure? You and your peer will have pair again."),
                  primaryButton: .default(Text("Yes")) {
                    viewModel.deleteSession()
                  },
                  secondaryButton: .default(Text("Cancel"))
            )
        }
    }

    private func unavailableView() -> some View {
        VStack {
            Text("Peer not detected")
                .bold()
                .multilineTextAlignment(.center)
                .padding(.bottom, 30)
            Text("Your peer is not in range or their device is not available")
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
