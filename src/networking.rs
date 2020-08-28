use core::fmt;
use log::*;
// use openssl::error::ErrorStack;
use reqwest::{
    blocking::{Client, Response},
    Error,
};
use serde::Deserialize;
use serde::{de::DeserializeOwned, Serialize};
use std::error;
use uuid::Uuid;

static BASE_URL: &str = "http://192.168.0.2:8000/";
// static BASE_URL: &str = "http://127.0.0.1:8000/";
// static BASE_URL: &str = "http://localhost.charlesproxy.com:8000/";

static UNKNOWN_HTTP_STATUS: u16 = 520;

////////////////////////////////////////////////////////////////////
// Common with server (TODO)
////////////////////////////////////////////////////////////////////

#[derive(Debug, Serialize, Deserialize)]
pub struct SessionKeyRequestParams {
    pub session_id: String,
    pub key: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct AckRequestParams {
    pub uuid: String,
    pub accepted: i32,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ParticipantsRequestParams {
    pub session_id: String,
    // TODO send uuid+signature too, so not anyone that has the session id can download the participants
}
#[derive(Debug, Serialize, Deserialize)]
pub struct DeleteRequestParams {
    pub peer_id: String,
    // TODO send uuid+signature too, so not anyone that has the session id can download the participants
}

#[derive(Debug, Clone)]
pub struct SessionKey {
    pub session_id: String,
    pub key: PublicKey,
}

#[derive(Debug, Serialize)]
pub struct Session {
    pub id: String,
    pub keys: Vec<PublicKey>,
}

#[derive(Debug, PartialEq, Eq, Clone, Deserialize, Serialize)]
pub struct PublicKey {
    pub str: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct JoinSessionResult {
    keys: Vec<PublicKey>,
}

#[derive(Serialize, Deserialize, Debug)]
struct AckResult {
    is_ready: bool,
}

#[derive(Serialize, Deserialize, Debug)]
struct HttpError {
    status: i32,
    msg: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct ParticipantsResult {
    keys: Vec<PublicKey>,
}

impl From<uuid::Error> for ServicesError {
    fn from(error: uuid::Error) -> Self {
        ServicesError::General(format!("{}", error))
    }
}

#[derive(Debug)]
pub enum ServicesError {
    General(String),
    Networking(NetworkingError),
    // Error(Error),
    // NotFound,
}

impl From<NetworkingError> for ServicesError {
    fn from(error: NetworkingError) -> Self {
        ServicesError::Networking(error)
    }
}

// impl From<ErrorStack> for ServicesError {
//     fn from(error: ErrorStack) -> Self {
//         ServicesError::General(format!("{:?}", error))
//     }
// }

pub trait VecExt<T> {
    fn map_now<U>(self, f: impl FnMut(T) -> U) -> Vec<U>;
}

impl<T> VecExt<T> for Vec<T> {
    fn map_now<U>(self, f: impl FnMut(T) -> U) -> Vec<U> {
        self.into_iter().map(f).collect()
    }
}

////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////

pub trait RemoteSessionApi {
    fn join_session(&self, session_key: SessionKey) -> Result<Session, NetworkingError>;
    fn ack(&self, uuid: String, count: i32) -> Result<bool, NetworkingError>;
    fn participants(&self, session_id: String) -> Result<Session, NetworkingError>;
    fn delete(&self, peer_id: String) -> Result<(), NetworkingError>;
}

pub struct RemoteSessionApiImpl {}

impl RemoteSessionApiImpl {
    // TODO is it bad to create a new client per request? should we cache it?
    fn create_client() -> Result<Client, Error> {
        reqwest::blocking::Client::builder()
            // .proxy(reqwest::Proxy::https("http://localhost:8888")?) // Charles proxy
            // .proxy(reqwest::Proxy::https("http://192.168.0.2:8888")?) // Charles proxy
            // .proxy(reqwest::Proxy::https(
            //     "http://localhost.charlesproxy.com:8888",
            // )?) // Charles proxy
            .build()
    }

    fn deserialize<T>(response: Response) -> Result<T, NetworkingError>
    where
        T: DeserializeOwned + std::fmt::Debug,
    {
        let status = response.status();
        if status.is_success() {
            let res = response.json::<T>();
            info!("Http response parsing result: {:?}", res);

            match res {
                Ok(obj) => Ok(obj),
                Err(error) => Err(NetworkingError {
                    http_status: UNKNOWN_HTTP_STATUS,
                    message: format!("Http internal error response: {:?}", error),
                }),
            }
        } else {
            let res = response.json::<HttpError>();
            info!("Http error response parsing result: {:?}", res);

            Err(NetworkingError {
                http_status: status.as_u16(),
                message: format!("Http error response: {:?}", res),
            })
        }
    }
}

impl RemoteSessionApi for RemoteSessionApiImpl {
    fn join_session(&self, session_key: SessionKey) -> Result<Session, NetworkingError> {
        info!("Networking: joining session, key: {:?}", session_key);

        let params = SessionKeyRequestParams {
            session_id: session_key.session_id.clone(),
            key: session_key.clone().key.str,
        };

        let url: &str = &format!("{}key", BASE_URL.to_owned())[..];
        let params_str = serde_json::to_string(&params).unwrap();

        let client = Self::create_client()?;
        let response = client
            .post(url)
            .header("Content-Type", "application/json")
            .body(params_str)
            .send()?;

        RemoteSessionApiImpl::deserialize(response).map(|r: JoinSessionResult| Session {
            id: session_key.session_id,
            keys: r.keys,
        })
    }

    fn ack(&self, uuid: String, stored_participants: i32) -> Result<bool, NetworkingError> {
        info!(
            "Networking: ack-ing session for: {:?}, participants: {:?}",
            uuid, stored_participants
        );

        let params = AckRequestParams {
            uuid,
            accepted: stored_participants,
        };

        let url: &str = &format!("{}ready", BASE_URL.to_owned())[..];
        let params_str = serde_json::to_string(&params).unwrap();

        let client = Self::create_client()?;
        let response = client
            .post(url)
            .header("Content-Type", "application/json")
            .body(params_str)
            .send()?;

        // TODO improve response handling: generic status: i32, err: string?, success: T?:  (?)
        // currently if JSON response isn't success, parsing to success type fails and does early exit
        // this works but not quite as intended: we want to handle success/error JSON payloads in the match below
        // currently app error messages are confusing, as we get parser errors, not the actual error
        // the other requests also have this problem.
        debug!("Ack-ed, networking response: {:?}", response);

        RemoteSessionApiImpl::deserialize(response).map(|r: AckResult| r.is_ready)
    }

    fn participants(&self, session_id: String) -> Result<Session, NetworkingError> {
        info!(
            "Networking: requesting participants, session id: {:?}",
            session_id
        );

        let params = ParticipantsRequestParams {
            session_id: session_id.clone(),
        };

        let url: &str = &format!("{}part", BASE_URL.to_owned())[..];
        let params_str = serde_json::to_string(&params).unwrap();

        let client = Self::create_client()?;
        let response = client
            .post(url)
            .header("Content-Type", "application/json")
            .body(params_str)
            .send()?;

        RemoteSessionApiImpl::deserialize(response).map(|r: ParticipantsResult| Session {
            id: session_id,
            keys: r.keys,
        })
    }

    fn delete(&self, peer_id: String) -> Result<(), NetworkingError> {
        info!("Networking: marking as deleted, peer id: {:?}", peer_id);

        let params = DeleteRequestParams {
            peer_id: peer_id.clone(),
        };

        let url: &str = &format!("{}del", BASE_URL.to_owned())[..];
        let params_str = serde_json::to_string(&params).unwrap();

        let client = Self::create_client()?;
        client
            .post(url)
            .header("Content-Type", "application/json")
            .body(params_str)
            .send()?;

        Ok(())
    }
}

#[derive(Debug, Clone)]
pub struct NetworkingError {
    pub http_status: u16,
    pub message: String,
}

impl fmt::Display for NetworkingError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{:?}", self)
    }
}

impl From<Error> for NetworkingError {
    fn from(error: Error) -> Self {
        NetworkingError {
            http_status: error
                .status()
                .map(|s| s.as_u16())
                .unwrap_or(UNKNOWN_HTTP_STATUS),
            message: error.to_string(),
        }
    }
}

impl error::Error for NetworkingError {}

#[cfg(test)]
mod tests {

    // TODO remove these tests
    // the db in the server of course doesn't get cleared between tests,
    // so state accumulates between tests. Current tests fail when run together.

    use super::*;
    use uuid::Uuid;

    //To run these tests use: 'cargo test -- --ignored'
    #[test]
    #[ignore]
    fn start_session_is_ok() {
        let api = RemoteSessionApiImpl {};
        let res = api.join_session(SessionKey {
            session_id: "1".to_owned(),
            key: PublicKey {
                str: "2".to_owned(),
            },
        });

        assert!(res.is_ok());

        let session = res.unwrap();
        assert_eq!(session.id, "1");
        assert_eq!(session.keys.len(), 1);
        assert_eq!(session.keys[0].str, "2");
    }

    #[test]
    #[ignore]
    fn start_and_join_session_is_ok() {
        let api = RemoteSessionApiImpl {};
        let res1 = api.join_session(SessionKey {
            session_id: "1".to_owned(),
            key: PublicKey {
                str: "2".to_owned(),
            },
        });

        assert!(res1.is_ok());

        let session1 = res1.unwrap();
        assert_eq!(session1.id, "1");
        assert_eq!(session1.keys.len(), 1);
        assert_eq!(session1.keys[0].str, "2");

        let res2 = api.join_session(SessionKey {
            session_id: "1".to_owned(),
            key: PublicKey {
                str: "3".to_owned(),
            },
        });

        let session2 = res2.unwrap();
        assert_eq!(session2.keys.len(), 2);
        assert_eq!(session2.keys[0].str, "2");
        assert_eq!(session2.keys[1].str, "3");
    }

    #[test]
    #[ignore]
    fn sessions_are_separate() {
        let api = RemoteSessionApiImpl {};
        let res1 = api.join_session(SessionKey {
            session_id: "1".to_owned(),
            key: PublicKey {
                str: "2".to_owned(),
            },
        });

        assert!(res1.is_ok());

        let session1 = res1.unwrap();
        assert_eq!(session1.keys.len(), 1);
        assert_eq!(session1.keys[0].str, "2");

        let res2 = api.join_session(SessionKey {
            session_id: "100".to_owned(),
            key: PublicKey {
                str: "3".to_owned(),
            },
        });

        let session2 = res2.unwrap();
        assert_eq!(session2.keys.len(), 1);
        assert_eq!(session2.keys[0].str, "3");
    }

    #[test]
    #[ignore]
    fn ack_session_is_err() {
        let api = RemoteSessionApiImpl {};
        // random uuid, so it will not find anything
        let res1 = api.ack(Uuid::new_v4().to_string(), 1);
        assert!(res1.is_err());
    }

    #[test]
    #[ignore]
    fn participants_is_ok() {
        let api = RemoteSessionApiImpl {};
        let res1 = api.participants("123".to_owned());
        assert!(res1.is_ok());
    }
}
