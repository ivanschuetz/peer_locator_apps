import SwiftUI

struct ContentView: View {
    @ObservedObject private var viewModel: ContentViewModel
    @Environment(\.colorScheme) var colorScheme

    init(viewModel: ContentViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        return VStack(alignment: .center) {
            Triangle()
                .fill(Color.white)
                .frame(width: 60, height: 60)
                .padding(.bottom, 10)
                .rotationEffect(viewModel.directionAngle)
            Text(viewModel.distance)
                .font(.system(size: 50, weight: .heavy))
                .foregroundColor(.white)
                .padding(.bottom, 50)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let bridge = PhoneBridgeImpl()
        let dispatcher = SessionDataDispatcherImpl(phoneBridge: bridge)
        ContentView(viewModel: ContentViewModel(sessionDataDispatcher: dispatcher))
    }
}
