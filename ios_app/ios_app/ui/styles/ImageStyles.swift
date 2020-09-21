import Foundation
import SwiftUI

private let iconDefaultSize: CGFloat = 20
private let iconLargeSize: CGFloat = 30

extension Image {
    
    func styleIconDefault() -> some View {
        resizable()
            .scaledToFill()
            .foregroundColor(.black)
            .frame(width: iconDefaultSize, height: iconDefaultSize, alignment: .center)
    }


    func styleIconLarge() -> some View {
        styleIconDefault()
            .frame(width: iconLargeSize, height: iconLargeSize, alignment: .center)
    }
}
