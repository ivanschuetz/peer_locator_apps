import UIKit
import SwiftUI

class HomeViewController: UIViewController {
    private let homeViewModel: HomeViewModel
    private let sessionViewModel: SessionViewModel

    init(homeViewModel: HomeViewModel, sessionViewModel: SessionViewModel) {
        self.homeViewModel = homeViewModel
        self.sessionViewModel = sessionViewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setRootSwiftUIView(view: TabsContainerView(homeViewModel: homeViewModel,
                                                   sessionViewModel: sessionViewModel))
    }
}
