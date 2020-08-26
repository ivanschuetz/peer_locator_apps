import SwiftUI
import Combine

struct TabsContainerView: View {
    @ObservedObject private var homeViewModel: MeetingViewModel
    @ObservedObject private var sessionViewModel: SessionViewModel

    init(homeViewModel: MeetingViewModel, sessionViewModel: SessionViewModel) {
        self.homeViewModel = homeViewModel
        self.sessionViewModel = sessionViewModel
    }

    var body: some View {
        TabView {
            MeetingView(viewModel: homeViewModel)
                .tabItem {
//                    Image(systemName: "")
                    Text("Menu")
                }

            SessionView(viewModel: sessionViewModel)
                .tabItem {
//                    Image(systemName: "")
                    Text("Session")
                }
        }
    }
}
