import SwiftUI
import UIKit
import Combine

struct SessionView: View {

    @ObservedObject private var viewModel: SessionViewModel

    init(viewModel: SessionViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack {
            Button("Create session", action: {
                viewModel.createSession()
            })
            Text(viewModel.sessionLink)
        }
    }
}

struct SessionView_Previews: PreviewProvider {
    static var previews: some View {
        SessionView(viewModel: SessionViewModel(sessionApi: NoopSessionApi()))
    }
}

class NoopSessionApi: SessionApi {
    func createSession() -> Result<Session, ServicesError> {
        .success(Session(id: "123", keys: []))
    }
}
