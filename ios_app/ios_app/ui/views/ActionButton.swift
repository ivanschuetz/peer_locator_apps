import Foundation
import SwiftUI

struct ActionButton: View {
    private let text: String
    private let action: () -> Void

    init(_ text: String, action: @escaping () -> Void) {
        self.text = text
        self.action = action
    }

    var body: some View {
        Button(action: action) { Text(text).styleButton() }
    }
}

struct ActionButton_Previews: PreviewProvider {
    static var previews: some View {
        ActionButton("Press!", action: {})
    }
}
