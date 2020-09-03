import Foundation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.settingsViewData) { setting in
                    view(setting: setting.data)
                }
            }
            .navigationBarTitle(Text("Settings"), displayMode: .inline)
        }
    }

    private func view(setting: UserSettingViewData) -> some View {
        switch setting {
        case let .textAction(text, action):
            return AnyView(actionTextView(text: text, action: action))
        }
    }

    private func actionTextView(text: String, action: UserSettingActionId) -> some View {
        Button(action: {
            viewModel.onAction(id: action)
        }, label: {
            Text(text).font(.system(size: 13))
        })
    }
}
