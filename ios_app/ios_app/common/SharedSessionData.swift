struct SharedSessionData: Equatable {
    let id: SessionId
    let isReady: SessionReady
    let createdByMe: Bool
}

// TODO maybe replace with SessionStatus { ready, notReady } ?
enum SessionReady {
    case yes, no
}
