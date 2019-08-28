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
mod changeset;
mod ellipticoin_api;
pub mod env;
mod gas_costs;
mod helpers;
mod memory;
mod result;
mod storage;
mod transaction;
mod vm;
pub use ellipticoin_api::{EllipticoinExternals, EllipticoinImportResolver};

pub use block_index::BlockIndex;
pub use changeset::Changeset;
pub use env::Env;
pub use memory::Memory;
pub use metered_wasmi::RuntimeValue;
pub use storage::Storage;
pub use transaction::{CompletedTransaction, Transaction};
pub use vm::{new_module_instance, State, VM};

pub use metered_wasmi::{ImportsBuilder, Module, ModuleInstance, NopExternals};
pub use redis::{pipe, Client, Commands, Connection, ControlFlow, PubSubCommands};
pub use rocksdb::ops::Open;
pub use rocksdb::{ReadOnlyDB, DB};
pub use rustler::resource::ResourceArc;
pub use rustler::types::atom::Atom;
pub use rustler::{Decoder, Encoder, NifResult, Term};
