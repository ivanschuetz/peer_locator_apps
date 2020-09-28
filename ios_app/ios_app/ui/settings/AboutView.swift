import SwiftUI
import SafariServices

struct AboutView: View {
    @ObservedObject var viewModel: AboutViewModel

    init(viewModelProvider: ViewModelProvider) {
        self.viewModel = viewModelProvider.about()
    }

    var body: some View {
        VStack {
            Text("Foo bar lorem ipsum")
                .padding(.bottom, 30)

            Button(action: {
                viewModel.onTwitterTap()
            }, label: {
                Text("Twitter").font(.system(size: 13))
            })
            .padding(.bottom, 30)
            Button(action: {
                viewModel.onContactTap()
            }, label: {
                Text("Contact").font(.system(size: 13))
            })
        }
        .defaultOuterHPadding()
        .navigationBarTitle(Text("About"), displayMode: .inline)
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
