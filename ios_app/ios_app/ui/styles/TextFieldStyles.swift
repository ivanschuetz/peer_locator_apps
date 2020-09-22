import Foundation
import SwiftUI

extension TextField {

    func styleDefault() -> some View {
        multilineTextAlignment(.center)
            .padding(.leading, 10)
            .padding(.trailing, 10)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray, lineWidth: 1))
    }
}
