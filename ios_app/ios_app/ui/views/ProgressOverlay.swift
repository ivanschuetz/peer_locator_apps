import Foundation
import SwiftUI

struct ProgressOverlay: View {
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
                .opacity(0.3)
                .allowsHitTesting(false)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
        }
    }
}
