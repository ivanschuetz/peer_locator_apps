use networking::{PublicKey, RemoteSessionApi, RemoteSessionApiImpl, ServicesError, SessionKey};

mod networking;

#[cfg(target_os = "android")]
mod ffi_android;
#[cfg(target_os = "ios")]
mod ffi_ios;

fn join_session_with_id(id: String) -> Result<Vec<PublicKey>, ServicesError> {
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
