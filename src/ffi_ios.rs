use crate::ack;
use crate::join_session_with_id;
use crate::{create_key_pair, networking::VecExt, start_session};
use core_foundation::{
    base::{TCFType, TCFTypeRef},
    string::{CFString, CFStringRef, __CFString},
};
use libc::c_char;
use log::*;
use mpsc::Receiver;
use serde::Serialize;
use std::{
    sync::mpsc::{self, Sender},
    thread,
};

#[repr(C)]
pub struct FFISessionResult {
    status: i32, // 1 -> success, 0 -> unknown error
    session_json: CFStringRef,
}

#[repr(C)]
pub struct FFIKeyPairResult {
    status: i32, // 1 -> success, 0 -> unknown error
    private: CFStringRef,
    public: CFStringRef,
}

#[derive(Debug, Serialize)]
pub struct FFISession {
    id: String,
    keys: Vec<String>,
}

#[repr(C)]
pub struct FFIAckResult {
    status: i32, // 1 -> success, 0 -> unknown error
}

#[no_mangle]
pub unsafe extern "C" fn ffi_create_key_pair() -> FFIKeyPairResult {
    let res = create_key_pair();

    match res {
        Ok(key_pair) => {
            let private_str = base64::encode(key_pair.private);
            let public_str = base64::encode(key_pair.public);
            FFIKeyPairResult {
                status: 1,
                private: private_str.to_CFStringRef_and_forget(),
                public: public_str.to_CFStringRef_and_forget(),
            }
        }
        Err(e) => {
            println!("Error creating session: {:?}", e);
            // TODO proper error result, not "error with empty success fields"
            let private_str = "".to_owned();
            let public_str = "".to_owned();
            FFIKeyPairResult {
                status: 0,
                private: private_str.to_CFStringRef_and_forget(),
                public: public_str.to_CFStringRef_and_forget(),
            }
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn ffi_create_session() -> FFISessionResult {
    let res = start_session();

    match res {
        Ok(session) => {
            let ffi_session = FFISession {
                id: session.id,
                keys: session.keys.map_now(|k| k.str),
            };
            let session_str = serde_json::to_string(&ffi_session).expect("Couldn't serialize keys");
            let cf_string_ref = session_str.to_CFStringRef_and_forget();

            FFISessionResult {
                status: 1,
                session_json: cf_string_ref,
            }
        }
        Err(e) => {
            println!("Error creating session: {:?}", e);
            let session_str = "";
            let cf_string_ref = session_str.to_owned().to_CFStringRef_and_forget();

            FFISessionResult {
                status: 0,
                session_json: cf_string_ref,
            }
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn ffi_join_session(session_id: *const c_char) -> FFISessionResult {
    let str: String = cstring_to_str(&session_id).into();
    let res = join_session_with_id(str);

    match res {
        Ok(session) => {
            let ffi_session = FFISession {
                id: session.id,
                keys: session.keys.map_now(|k| k.str),
            };
            let session_str = serde_json::to_string(&ffi_session).expect("Couldn't serialize keys");
            let cf_string_ref = session_str.to_CFStringRef_and_forget();

            FFISessionResult {
                status: 1,
                session_json: cf_string_ref,
            }
        }
        Err(e) => {
            println!("Error creating session: {:?}", e);
            let session_str = "";
            let cf_string_ref = session_str.to_owned().to_CFStringRef_and_forget();

            FFISessionResult {
                status: 0,
                session_json: cf_string_ref,
            }
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn ffi_ack(uuid: *const c_char, stored_participants: i32) -> FFIAckResult {
    let uuid_str: String = cstring_to_str(&uuid).into();
    let res = ack(uuid_str, stored_participants);

    match res {
        Ok(_) => FFIAckResult { status: 1 },
        Err(e) => {
            println!("Error acking: {:?}", e);
            FFIAckResult { status: 0 }
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn greet(who: *const c_char) -> CFStringRef {
    let str: String = cstring_to_str(&who).into();
    to_cf_str(format!("Hello 👋 {}!", str))
}

#[no_mangle]
pub unsafe extern "C" fn add_values(value1: i32, value2: i32) -> i32 {
    info!("Passed value1: {}, value2: {}", value1, value2);
    value1 + value2
}

#[no_mangle]
pub unsafe extern "C" fn pass_struct(object: *const ParamStruct) {
    info!("Received struct from iOS: {:?}", object);
}

#[no_mangle]
pub unsafe extern "C" fn return_struct() -> ReturnStruct {
    ReturnStruct {
        string: to_cf_str("my string parameter".to_owned()),
        int: 123,
    }
}

pub static mut CALLBACK_SENDER: Option<Sender<String>> = None;

#[no_mangle]
pub unsafe extern "C" fn register_callback(callback: unsafe extern "C" fn(CFStringRef)) {
    register_callback_internal(Box::new(callback));

    // Let's send a message immediately, to test it
    send_to_callback("Hello callback!".to_owned());
}

// Convert C string to Rust string slice
unsafe fn cstring_to_str<'a>(cstring: &'a *const c_char) -> &str {
    if cstring.is_null() {
        // Of course in a real project you'd return Result instead
        panic!("cstring is null")
    }

    let raw = ::std::ffi::CStr::from_ptr(*cstring);
    raw.to_str().expect("Couldn't convert c string to slice")
}

fn to_cf_str(str: String) -> CFStringRef {
    let cf_string = CFString::new(&str);
    let cf_string_ref = cf_string.as_concrete_TypeRef();
    ::std::mem::forget(cf_string);
    cf_string_ref
}

unsafe fn send_to_callback(string: String) {
    match &CALLBACK_SENDER {
        Some(s) => {
            s.send(string).expect("Couldn't send message to callback!");
        }
        None => {
            info!("No callback registered");
        }
    }
}

fn register_callback_internal(callback: Box<dyn MyCallback>) {
    // Make callback implement Send (marker for thread safe, basically) https://doc.rust-lang.org/std/marker/trait.Send.html
    let my_callback =
        unsafe { std::mem::transmute::<Box<dyn MyCallback>, Box<dyn MyCallback + Send>>(callback) };

    // Create channel
    let (tx, rx): (Sender<String>, Receiver<String>) = mpsc::channel();

    // Save the sender in a static variable, which will be used to push elements to the callback
    unsafe {
        CALLBACK_SENDER = Some(tx);
    }

    // Thread waits for elements pushed to SENDER and calls the callback
    thread::spawn(move || {
        for string in rx.iter() {
            let cf_string = to_cf_str(string);
            my_callback.call(cf_string)
        }
    });
}

pub trait MyCallback {
    fn call(&self, par: CFStringRef);
}

impl MyCallback for unsafe extern "C" fn(CFStringRef) {
    fn call(&self, par: CFStringRef) {
        unsafe {
            self(par);
        }
    }
}

#[repr(C)]
#[derive(Debug)]
pub struct ParamStruct {
    string: *const c_char,
    int: i32,
}
#[repr(C)]
#[derive(Debug)]
pub struct ReturnStruct {
    string: CFStringRef,
    int: i32,
}

trait StringFFIAdditions {
    fn to_CFStringRef_and_forget(self) -> *const __CFString;
}

impl StringFFIAdditions for String {
    fn to_CFStringRef_and_forget(self) -> *const __CFString {
        let session_cf_string = CFString::new(&self.to_owned());
        let cf_string_ref = session_cf_string.as_concrete_TypeRef();
        ::std::mem::forget(session_cf_string);
        cf_string_ref
    }
}
