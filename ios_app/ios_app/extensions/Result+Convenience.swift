import Foundation

extension Result {

    func isFailure() -> Bool {
        switch self {
        case .success:
            return false
        case .failure:
            return true
        }
    }
}
