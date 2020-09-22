import Foundation

extension String {
    func removeAllImmutable(where pred: (Character) -> Bool) -> Self {
        var mutSelf = self
        mutSelf.removeAll { pred($0) }
        return mutSelf
    }
}
