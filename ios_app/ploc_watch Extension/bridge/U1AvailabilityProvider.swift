import Foundation


enum UIAvailability {
    case phoneAndWatch, watch, phone, none
}

// Resolves via bridge UIAvailability
protocol U1AvailabilityProvider {
}

class U1AvailabilityProviderImpl: U1AvailabilityProvider {
}
