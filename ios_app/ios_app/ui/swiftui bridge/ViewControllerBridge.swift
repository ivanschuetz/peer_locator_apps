import SwiftUI

struct ViewControllerBridge: UIViewControllerRepresentable {
    @Binding var isActive: Bool
    let action: (UIViewController, Bool) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        return UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        action(uiViewController, isActive)
    }
}
