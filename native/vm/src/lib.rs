#![feature(custom_attribute, plugin, rustc_private)]
#[macro_use]
extern crate lazy_static;
extern crate heck;
extern crate redis;
extern crate rustler;
extern crate serde;
extern crate serde_cbor;
extern crate serialize;
extern crate sha3;
extern crate time;
extern crate wasmi;
extern crate rocksdb;

mod block_index;
mod ellipticoin_api;
pub mod env;
mod helpers;
mod memory;
mod storage;
mod transaction;
mod vm;
pub use ellipticoin_api::EllipticoinAPI;

pub use env::Env;
pub use memory::Memory;
pub use storage::Storage;
pub use transaction::{run_transaction, CompletedTransaction, Transaction};
pub use vm::VM;
pub use wasmi::RuntimeValue;

pub use redis::{pipe, Client, Commands, Connection, ControlFlow, PubSubCommands};
pub use rocksdb::{DB};
pub use rocksdb::ops::Open;
pub use rustler::resource::ResourceArc;
pub use rustler::types::atom::Atom;
pub use rustler::{Decoder, Encoder, NifResult, Term};
