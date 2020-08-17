import Foundation
import Combine
import SwiftUI

class SessionViewModel: ObservableObject {
    private let sessionApi: SessionApi

    @Published var sessionLink: String = ""

    init(sessionApi: SessionApi) {
        self.sessionApi = sessionApi
    }

    func createSession() {
        switch sessionApi.createSession() {
        case .success(let session):
            sessionLink = session.id
        case .failure(let error):
            log.e("Failure creating session! \(error)", .session)
            // TODO notification
        }
    }
}
