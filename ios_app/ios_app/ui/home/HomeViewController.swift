import UIKit
import SwiftUI

class HomeViewController: UIViewController {

    private let viewModel: HomeViewModel
    private let sessionViewModel: SessionViewModel

    init(viewModel: HomeViewModel, sessionViewModel: SessionViewModel) {
        self.viewModel = viewModel
        self.sessionViewModel = sessionViewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setRootSwiftUIView(view: HomeView(viewModel: viewModel, sessionViewModel: sessionViewModel))
    }
}
