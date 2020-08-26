use crate::networking::{
    PublicKey, RemoteSessionApi, RemoteSessionApiImpl, ServicesError, Session, SessionKey,
};
// use openssl::rsa::Rsa;

use log::*;
use uuid::Uuid;

#[derive(Debug, Clone)]
pub struct KeyPair {
    pub private: Vec<u8>,
    pub public: Vec<u8>,
}

pub fn start_session(session_id: String, key: String) -> Result<Session, ServicesError> {
    // TODO check if id already exists in db?

    let res = join_session_with_id(session_id, key);
    debug!("Start session res: {:?}", res);
    res
}

pub fn join_session_with_id(id: String, key: String) -> Result<Session, ServicesError> {
    debug!("Joining session with id: {}, key: {}", id, key);
    let api = RemoteSessionApiImpl {};
    let res = api
        .join_session(SessionKey {
            session_id: id,
            key: PublicKey { str: key },
        })
        .map_err(ServicesError::from);
    debug!("Join session res: {:?}", res);
    res
}

pub fn create_key_pair() -> Result<KeyPair, ServicesError> {
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

pub fn ack(uuid: String, stored_participants: i32) -> Result<bool, ServicesError> {
    let api = RemoteSessionApiImpl {};
    let res = api
        .ack(uuid, stored_participants)
        .map_err(ServicesError::from);

    debug!("Ack res: {:?}", res);
    res
}

pub fn participants(session_id: String) -> Result<Session, ServicesError> {
    let api = RemoteSessionApiImpl {};
    let res = api.participants(session_id).map_err(ServicesError::from);
    debug!("Participants res: {:?}", res);
    res
}
