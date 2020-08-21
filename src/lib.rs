use networking::{
    PublicKey, RemoteSessionApi, RemoteSessionApiImpl, ServicesError, Session, SessionKey,
};
// use openssl::rsa::Rsa;
use uuid::Uuid;

mod networking;

#[cfg(target_os = "android")]
mod ffi_android;
#[cfg(any(target_os = "ios", target_os = "macos"))]
mod ffi_ios;

#[derive(Debug, Clone)]
struct KeyPair {
    private: Vec<u8>,
    public: Vec<u8>,
}

fn start_session(key: String) -> Result<Session, ServicesError> {
    let uuid = Uuid::new_v4();
    // TODO check if already exists in db?

    join_session_with_id(uuid.to_string(), key)
}

fn create_key_pair() -> Result<KeyPair, ServicesError> {
    // it was not possible to get rust-openssl working:
    // https://stackoverflow.com/questions/63513401/how-to-use-rust-openssl-on-ios
    // https://github.com/sfackler/rust-openssl/issues/1331
    // for now generating keys in the apps
    // note also that we should use EC instead of RSA (doing this now on iOS)

    // let rsa = Rsa::generate(4096)?;

    // let private_key = rsa.private_key_to_pem()?;
    // let public_key = rsa.public_key_to_pem()?;

    // Ok(KeyPair {
    //     private: private_key,
    //     public: public_key,
    // })
    Ok(KeyPair {
        private: vec![],
        public: vec![],
    })
}

fn join_session_with_id(id: String, key: String) -> Result<Session, ServicesError> {
    let api = RemoteSessionApiImpl {};
    api.join_session(SessionKey {
        session_id: id,
        key: PublicKey { str: key },
    })
    .map_err(ServicesError::from)
}

fn ack(uuid: String, stored_participants: i32) -> Result<bool, ServicesError> {
    let api = RemoteSessionApiImpl {};
    let uuid = Uuid::parse_str(uuid.as_ref())?;
    api.ack(uuid, stored_participants)
        .map_err(ServicesError::from)
}

fn participants(session_id: String) -> Result<Session, ServicesError> {
    let api = RemoteSessionApiImpl {};
    api.participants(session_id).map_err(ServicesError::from)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn creates_key_pair() {
        let res = create_key_pair();

        assert!(res.is_ok());
        let key_pair = res.unwrap();
        assert_eq!(key_pair.private.is_empty(), false);
        assert_eq!(key_pair.public.is_empty(), false);
    }
}
