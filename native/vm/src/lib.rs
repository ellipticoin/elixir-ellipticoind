#![feature(
    custom_attribute,
)]
// #[macro_use] extern crate rustler;
#[macro_use] extern crate lazy_static;
extern crate sha3;
extern crate redis;
extern crate wasmi;
#[macro_use] extern crate rustler;
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

pub use rustler::{Env, Term, NifResult, Encoder, Decoder};
pub use rustler::types::atom::{Atom};
pub use redis::{
    Connection,
    Client,
    Commands,
};
pub use rustler::resource::ResourceArc;


pub fn on_load<'a>(env: Env<'a>, load_info: Term<'a>) -> bool {
    resource_struct_init!(RedisHandle, env);
    true
}
pub use db::rw_lock_write_guard_redis::RedisHandle;
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
