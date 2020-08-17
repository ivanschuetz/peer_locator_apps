use core::fmt;
use log::*;
use reqwest::{blocking::Client, Error};
use serde::Deserialize;
use serde::Serialize;
use std::error;

static BASE_URL: &str = "http://127.0.0.1:8000/";

static UNKNOWN_HTTP_STATUS: u16 = 520;

////////////////////////////////////////////////////////////////////
// Common with server (TODO)
////////////////////////////////////////////////////////////////////

#[derive(Debug, Serialize, Deserialize)]
pub struct SessionKeyRequestParams {
    pub session_id: String,
    pub key: String,
}

#[derive(Debug)]
pub struct SessionKey {
    pub session_id: String,
    pub key: PublicKey,
}

#[derive(Debug, PartialEq, Eq, Clone, Deserialize, Serialize)]
pub struct PublicKey {
    pub str: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct JoinSessionResult {
    status: i32,
    keys: Vec<PublicKey>,
}

#[derive(Debug)]
pub enum ServicesError {
    General(String),
    Networking(NetworkingError),
    Error(Error),
    NotFound,
}

impl From<NetworkingError> for ServicesError {
    fn from(error: NetworkingError) -> Self {
        ServicesError::Networking(error)
    }
}

////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////

pub trait RemoteSessionApi {
    fn join_session(&self, session_key: SessionKey) -> Result<Vec<PublicKey>, NetworkingError>;
}

pub struct RemoteSessionApiImpl {}

impl RemoteSessionApiImpl {
    fn create_client() -> Result<Client, Error> {
        reqwest::blocking::Client::builder()
            // .proxy(reqwest::Proxy::https("http://localhost:8888")?) // Charles proxy
            .build()
    }
}

impl RemoteSessionApi for RemoteSessionApiImpl {
    fn join_session(&self, session_key: SessionKey) -> Result<Vec<PublicKey>, NetworkingError> {
        info!("Joining session, key: {:?}", session_key);

        let params = SessionKeyRequestParams {
            session_id: session_key.session_id,
            key: session_key.key.str,
        };

        let url: &str = &format!("{}key", BASE_URL.to_owned())[..];
        let params_str = serde_json::to_string(&params).unwrap();

        let client = Self::create_client()?;
        let response = client
            .post(url)
            .header("Content-Type", "application/json")
            .body(params_str)
            .send()?;

        let res = response.json::<JoinSessionResult>()?;
        info!("Retrieved keys, networking result: {:?}", res);

        match res.status {
            1 => Ok(res.keys),
            _ => Err(NetworkingError {
                http_status: UNKNOWN_HTTP_STATUS,
                message: format!("Http internal error code: {}", res.status),
            }),
        }
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

        let keys = res.unwrap();
        assert_eq!(keys.len(), 1);
        assert_eq!(keys[0].str, "2");
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

        let keys1 = res1.unwrap();
        assert_eq!(keys1.len(), 1);
        assert_eq!(keys1[0].str, "2");

        let res2 = api.join_session(SessionKey {
            session_id: "1".to_owned(),
            key: PublicKey {
                str: "3".to_owned(),
            },
        });

        let keys2 = res2.unwrap();
        assert_eq!(keys2.len(), 2);
        assert_eq!(keys2[0].str, "2");
        assert_eq!(keys2[1].str, "3");
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

        let keys1 = res1.unwrap();
        assert_eq!(keys1.len(), 1);
        assert_eq!(keys1[0].str, "2");

        let res2 = api.join_session(SessionKey {
            session_id: "100".to_owned(),
            key: PublicKey {
                str: "3".to_owned(),
            },
        });

        let keys2 = res2.unwrap();
        assert_eq!(keys2.len(), 1);
        assert_eq!(keys2[0].str, "3");
    }
}
