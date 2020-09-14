import Foundation

extension Array {
    var only: Element? {
        if count > 1 {
            fatalError("only() called on array with more than 1 element: \(self)")
        }
        return first
    }
}
