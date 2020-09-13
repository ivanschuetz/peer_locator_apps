import Foundation

extension Sequence {

    // Like contains/any/exists, but evaluates all the elements
    // Used if we want to perform side effects
    func evaluate(_ pred: (Element) -> Bool) -> Bool {
        var anyIsTrue = false
        for e in self {
            if pred(e) {
                anyIsTrue = true
            }
        }
        return anyIsTrue
    }
}
