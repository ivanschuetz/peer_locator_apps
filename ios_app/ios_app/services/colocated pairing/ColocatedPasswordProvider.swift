import Foundation

// TODO reactive password getter?
protocol ColocatedPasswordProvider {
    func password() -> ColocatedPeeringPassword?
    func savePassword(_ password: ColocatedPeeringPassword)
}

class ColocatedPasswordProviderImpl: ColocatedPasswordProvider {
    private var pw: ColocatedPeeringPassword?

    func password() -> ColocatedPeeringPassword? {
//        pw
        // TODO remove after we implement qr code
        ColocatedPeeringPassword(value: "123")
    }

    func savePassword(_ pw: ColocatedPeeringPassword) {
        self.pw = pw
    }
}
