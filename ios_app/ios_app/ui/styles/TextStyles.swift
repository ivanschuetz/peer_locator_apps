import Foundation
import SwiftUI

private let actionPaddingV: CGFloat = 12
private let actionPaddingH: CGFloat = 16

extension Text {

    func styleButton() -> some View {
        padding(.top, actionPaddingV)
            .frame(minWidth: 100, idealWidth: nil, maxWidth: nil, minHeight: nil, idealHeight: nil, maxHeight: nil,
                   alignment: .center)
            .padding(.bottom, actionPaddingV)
            .padding(.leading, actionPaddingH)
            .padding(.trailing, actionPaddingH)
            .background(Color.black)
            .foregroundColor(Color.white)
            .cornerRadius(14)
    }

    func styleDelete() -> some View {
        styleButton()
            .background(Color.red)
    }
}
