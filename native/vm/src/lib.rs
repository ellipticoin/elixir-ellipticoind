#![feature(
    custom_attribute,
)]
#[macro_use] extern crate lazy_static;
extern crate time;
extern crate heck;
extern crate rustler;
extern crate sha3;
extern crate redis;
extern crate wasmi;
extern crate serde_cbor;

mod ellipticoin_api;
mod helpers;
mod vm;
mod db;
mod transaction;
pub use ellipticoin_api::{
    EllipticoinAPI,
};

pub use transaction::{
    Transaction,
    transaction_from_slice,
    run_transaction,
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
    pipe,
};
pub use rustler::resource::ResourceArc;
