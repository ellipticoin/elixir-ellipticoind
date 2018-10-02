#![feature(
    custom_attribute,
)]
// #[macro_use] extern crate rustler;
#[macro_use] extern crate lazy_static;
extern crate sha3;
extern crate redis;
extern crate wasmi;
extern crate serde_cbor;

mod ellipticoin_api;
mod helpers;
mod vm;
mod db;
pub use ellipticoin_api::{
    EllipticoinAPI,
};
pub use vm::{
    VM,
};
pub use db::{
    DB,
};
pub use wasmi::{
    RuntimeValue,
};

pub use redis::{
    Connection,
    Client,
    Commands,
};

// use db::{DB};
// use serde_cbor::{to_vec, Value};
// use redis::Commands;
// use std::collections::HashMap;
// use vm::VM;
// use std::io::Write;
// use wasmi::*;
// use ellipticoin_api::ElipticoinAPI;
// use std::ops::Deref;
// use std::sync::{RwLock,Arc};
// use db::redis::RedisHandle;
// use sha3::{Digest, Sha3_256};
