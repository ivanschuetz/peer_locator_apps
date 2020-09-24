import Foundation
import SwiftUI

struct SettingsImage: View {
    var body: some View {
        Image(systemName: "gearshape")
            .resizable()
            .foregroundColor(Color.icon)
            .padding(.trailing, 30)
    }
}
