import Foundation
import SwiftUI

private let actionPaddingV: CGFloat = 12
private let actionPaddingH: CGFloat = 16

extension View {

    func defaultOuterHPadding() -> some View {
        padding(.leading, hOuterPaddingDefault).padding(.trailing, hOuterPaddingDefault)
    }
}
