#![feature(custom_attribute, plugin, rustc_private)]
#[macro_use]
extern crate lazy_static;
extern crate heck;
extern crate redis;
extern crate rustler;
extern crate serde;
extern crate serde_cbor;
extern crate sha3;
extern crate time;
extern crate wasmi;

mod db;
mod ellipticoin_api;
mod helpers;
mod transaction;
mod vm;
pub mod env;
pub use ellipticoin_api::EllipticoinAPI;

pub use db::DB;
pub use env::Env;
pub use transaction::{run_transaction, Transaction, CompletedTransaction};
pub use vm::VM;
pub use wasmi::RuntimeValue;

pub use redis::{pipe, Client, Commands, Connection, ControlFlow, PubSubCommands};
pub use rustler::resource::ResourceArc;
pub use rustler::types::atom::Atom;
pub use rustler::{Decoder, Encoder, NifResult, Term};
