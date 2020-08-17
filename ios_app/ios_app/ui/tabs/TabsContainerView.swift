import SwiftUI
import Combine

struct TabsContainerView: View {
    @ObservedObject private var homeViewModel: HomeViewModel
    @ObservedObject private var sessionViewModel: SessionViewModel

    init(homeViewModel: HomeViewModel, sessionViewModel: SessionViewModel) {
        self.homeViewModel = homeViewModel
        self.sessionViewModel = sessionViewModel
    }

    var body: some View {
        TabView {
            HomeView(viewModel: homeViewModel)
                .tabItem {
//                    Image(systemName: "")
                    Text("Menu")
                }

            SessionView(viewModel: sessionViewModel)
                .tabItem {
//                    Image(systemName: "")
                    Text("Order")
                }
        }
    }
}
