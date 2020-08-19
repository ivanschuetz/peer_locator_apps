use networking::{
    PublicKey, RemoteSessionApi, RemoteSessionApiImpl, ServicesError, Session, SessionKey,
};
use uuid::Uuid;

mod networking;

#[cfg(target_os = "android")]
mod ffi_android;
#[cfg(target_os = "ios")]
mod ffi_ios;

fn start_session() -> Result<Session, ServicesError> {
    let uuid = Uuid::new_v4();
    // TODO check if already exists in db?

    join_session_with_id(uuid.to_string())
}

fn join_session_with_id(id: String) -> Result<Session, ServicesError> {
    let api = RemoteSessionApiImpl {};
    let key = "123"; // TODO create
    api.join_session(SessionKey {
        session_id: id,
        key: PublicKey {
            str: key.to_owned(),
        },
    })
    .map_err(ServicesError::from)
}

fn ack(uuid: String, stored_participants: i32) -> Result<(), ServicesError> {
    let api = RemoteSessionApiImpl {};
    let uuid = Uuid::parse_str(uuid.as_ref())?;
    api.ack(uuid, stored_participants)
        .map_err(ServicesError::from)
}
