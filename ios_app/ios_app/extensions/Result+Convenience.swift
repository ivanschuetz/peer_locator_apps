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

    func asOptional() -> Optional<Success> {
        switch self {
        case .success(let success): return success
        case .failure(let e):
            log.e("Converting failure with error: \(e) to nil", .env)
            return nil
        }
    }
}
