#![feature(custom_attribute, plugin, rustc_private)]
extern crate heck;
extern crate metered_wasmi;
extern crate redis;
extern crate rocksdb;
extern crate rustler;
extern crate serde;
extern crate serde_cbor;
extern crate serialize;
extern crate sha3;
extern crate time;

mod block_index;
mod ellipticoin_api;
pub mod env;
mod helpers;
mod memory;
mod result;
mod changeset;
mod storage;
mod transaction;
mod vm;
mod gas_costs;
pub use ellipticoin_api::{EllipticoinExternals, EllipticoinImportResolver};

pub use block_index::BlockIndex;
pub use env::Env;
pub use memory::Memory;
pub use metered_wasmi::RuntimeValue;
pub use storage::Storage;
pub use transaction::{CompletedTransaction, Transaction};
pub use changeset::Changeset;
pub use vm::{State, VM, new_module_instance};

pub use redis::{pipe, Client, Commands, Connection, ControlFlow, PubSubCommands};
pub use rocksdb::ops::Open;
pub use rocksdb::{ReadOnlyDB, DB};
pub use rustler::resource::ResourceArc;
pub use rustler::types::atom::Atom;
pub use rustler::{Decoder, Encoder, NifResult, Term};
pub use metered_wasmi::{NopExternals, ImportsBuilder, Module, ModuleInstance};
