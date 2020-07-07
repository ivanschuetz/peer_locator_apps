import UIKit
import SwiftUI

class HomeViewController: UIViewController {

    private let viewModel = HomeViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setRootSwiftUIView(view: HomeView(viewModel: viewModel))
    }
}
