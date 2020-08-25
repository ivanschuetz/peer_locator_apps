mod globals;
mod logger;
mod networking;

#[cfg(target_os = "android")]
mod ffi_android;
#[cfg(any(target_os = "ios", target_os = "macos"))]
mod ffi_ios;

// Commented since key pair is not functional
// returning empty values, as open ssl import breaks apps (at least iOS)

// #[cfg(test)]
// mod tests {
//     use super::*;

//     #[test]
//     fn creates_key_pair() {
//         let res = create_key_pair();

//         assert!(res.is_ok());
//         let key_pair = res.unwrap();
//         assert_eq!(key_pair.private.is_empty(), false);
//         assert_eq!(key_pair.public.is_empty(), false);
//     }
// }
