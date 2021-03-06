use std::time::Duration;

use crate::globals::ClientSessionKey;
use backoff::{ExponentialBackoff, Operation};
use log::*;
use ploc_common::{
    errors::{NetworkingError, UNKNOWN_HTTP_STATUS},
    model_types::PublicKey,
    networking_types::{
        AckRequestParams, AckSessionResult, HttpError, JoinSessionResult,
        ParticipantsRequestParams, ParticipantsResult, PeerDeleteSesionParams,
        SessionKeyRequestParams,
    },
};
use reqwest::{
    blocking::{Client, Response},
    Error,
};
use serde::{de::DeserializeOwned, Serialize};

static BASE_URL: &str = "http://192.168.0.123:8000/";
// static BASE_URL: &str = "http://127.0.0.1:8000/";
// static BASE_URL: &str = "http://localhost.charlesproxy.com:8000/";

#[derive(Debug, Serialize)]
pub struct Session {
    pub id: String,
    pub keys: Vec<PublicKey>,
}

pub trait RemoteSessionApi {
    fn join_session(&self, session_key: ClientSessionKey) -> Result<Session, NetworkingError>;
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

    fn backoff() -> ExponentialBackoff {
        ExponentialBackoff {
            max_elapsed_time: Some(Duration::new(5, 0)),
            ..ExponentialBackoff::default()
        }
    }
}

impl RemoteSessionApi for RemoteSessionApiImpl {
    fn join_session(&self, session_key: ClientSessionKey) -> Result<Session, NetworkingError> {
        info!("Networking: joining session, key: {:?}", session_key);

        let params = SessionKeyRequestParams {
            session_id: session_key.session_id.clone(),
            key: session_key.clone().key.str,
        };

        let url: &str = &format!("{}key", BASE_URL.to_owned())[..];
        let params_str = serde_json::to_string(&params).unwrap();

        let client = Self::create_client()?;

        let mut op = || -> Result<Response, backoff::Error<NetworkingError>> {
            let response = client
                .post(url)
                .header("Content-Type", "application/json")
                .body(params_str.clone())
                .send()
                .map_err(NetworkingError::from)?;

            Ok(response)
        };

        let response = op.retry(&mut Self::backoff()).map_err(|e| e.error())?;

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

        let mut op = || -> Result<Response, backoff::Error<NetworkingError>> {
            let response = client
                .post(url)
                .header("Content-Type", "application/json")
                .body(params_str.clone())
                .send()
                .map_err(NetworkingError::from)?;

            Ok(response)
        };
        let response = op.retry(&mut Self::backoff()).map_err(|e| e.error())?;

        // TODO improve response handling: generic status: i32, err: string?, success: T?:  (?)
        // currently if JSON response isn't success, parsing to success type fails and does early exit
        // this works but not quite as intended: we want to handle success/error JSON payloads in the match below
        // currently app error messages are confusing, as we get parser errors, not the actual error
        // the other requests also have this problem.
        debug!("Ack-ed, networking response: {:?}", response);

        RemoteSessionApiImpl::deserialize(response).map(|r: AckSessionResult| r.is_ready)
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

        let mut op = || -> Result<Response, backoff::Error<NetworkingError>> {
            let response = client
                .post(url)
                .header("Content-Type", "application/json")
                .body(params_str.clone())
                .send()
                .map_err(NetworkingError::from)?;

            Ok(response)
        };
        let response = op.retry(&mut Self::backoff()).map_err(|e| e.error())?;

        RemoteSessionApiImpl::deserialize(response).map(|r: ParticipantsResult| Session {
            id: session_id,
            keys: r.keys,
        })
    }

    fn delete(&self, peer_id: String) -> Result<(), NetworkingError> {
        info!("Networking: marking as deleted, peer id: {:?}", peer_id);

        let params = PeerDeleteSesionParams {
            peer_id: peer_id.clone(),
        };

        let url: &str = &format!("{}del", BASE_URL.to_owned())[..];
        let params_str = serde_json::to_string(&params).unwrap();

        let client = Self::create_client()?;

        let mut op = || -> Result<Response, backoff::Error<NetworkingError>> {
            let response = client
                .post(url)
                .header("Content-Type", "application/json")
                .body(params_str.clone())
                .send()
                .map_err(NetworkingError::from)?;

            Ok(response)
        };
        op.retry(&mut Self::backoff()).map_err(|e| e.error())?;

        Ok(())
    }
}

#[cfg(test)]
mod tests {

    // TODO remove these tests
    // the db in the server of course doesn't get cleared between tests,
    // so state accumulates between tests. Current tests fail when run together.

    use super::*;
    use crate::globals::ClientSessionKey;
    use ploc_common::model_types::PublicKey;
    use uuid::Uuid;
    //To run these tests use: 'cargo test -- --ignored'
    #[test]
    #[ignore]
    fn start_session_is_ok() {
        let api = RemoteSessionApiImpl {};
        let res = api.join_session(ClientSessionKey {
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
        let res1 = api.join_session(ClientSessionKey {
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

        let res2 = api.join_session(ClientSessionKey {
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
        let res1 = api.join_session(ClientSessionKey {
            session_id: "1".to_owned(),
            key: PublicKey {
                str: "2".to_owned(),
            },
        });

        assert!(res1.is_ok());

        let session1 = res1.unwrap();
        assert_eq!(session1.keys.len(), 1);
        assert_eq!(session1.keys[0].str, "2");

        let res2 = api.join_session(ClientSessionKey {
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

trait WithWrappedError<E> {
    fn error(self) -> E;
}

impl<E> WithWrappedError<E> for backoff::Error<E> {
    fn error(self) -> E {
        match self {
            backoff::Error::Permanent(err) | backoff::Error::Transient(err) => err,
        }
    }
}
