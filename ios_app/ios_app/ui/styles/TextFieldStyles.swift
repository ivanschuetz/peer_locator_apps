import Foundation
import SwiftUI

extension TextField {

    func styleDefault() -> some View {
        multilineTextAlignment(.center)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray, lineWidth: 1))
    }
}
