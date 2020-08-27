import Foundation

class NumberFormatters {
    static let oneDecimal = OneDecimalFormatter()
}

final class OneDecimalFormatter: NumberFormatter {
    override init() {
        super.init()
        roundingMode = .down
        numberStyle = .decimal
        maximumFractionDigits = 1
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    func string(from number: Float) -> String? {
        string(from: number as NSNumber)
    }
}
