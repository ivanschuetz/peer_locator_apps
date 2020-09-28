import Foundation
import SwiftUI
import SafariServices

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    private var viewModelProvider: ViewModelProvider

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.settings()
        self.viewModelProvider = viewModelProvider
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.settingsViewData) { setting in
                    view(setting: setting.data)
                }
            }
            .navigationBarTitle(Text("Settings"), displayMode: .inline)

//            https://stackoverflow.com/a/62244449/930450
            .background(
                ViewControllerBridge(isActive: $viewModel.presentingSafariView) { vc, active in
                    if active {
                        let safariVC = SFSafariViewController(url: viewModel.safariViewUrl)
                        safariVC.modalPresentationStyle = .pageSheet
                        vc.present(safariVC, animated: true) {
                            viewModel.presentingSafariView = false
                        }
                    }
                }
                .frame(width: 0, height: 0)
            )
        }
    }

    private func view(setting: UserSettingViewData) -> some View {
        switch setting {
        case let .action(text, action):
            return AnyView(actionTextView(text: text, action: action))
        case let .navigationAction(text, action):
            return AnyView(navigationActionTextView(text: text, target: action))

        }
    }

    private func actionTextView(text: String, action: UserSettingActionId) -> some View {
        Button(action: {
            viewModel.onAction(id: action)
        }, label: {
            Text(text).font(.system(size: 13))
        })
    }

    private func navigationActionTextView(text: String, target: UserSettingNavigationTarget) -> some View {
        NavigationLink(destination: Lazy(destinationView(destination: target))) {
            Text(text)
        }
    }

    private func destinationView(destination: UserSettingNavigationTarget) -> some View {
        switch destination {
        case .about: return AnyView(AboutView(viewModelProvider: viewModelProvider))
        }
    }
}
