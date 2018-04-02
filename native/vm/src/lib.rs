#![feature(
    custom_attribute,
)]
#[macro_use] extern crate rustler;
#[macro_use] extern crate lazy_static;
extern crate redis;
extern crate rocksdb;
extern crate wasmi;
extern crate serde_cbor;

mod elipticoin_api;
mod helpers;
mod vm;

use serde_cbor::{from_slice, to_vec, Value};
use redis::Commands;
use std::collections::BTreeMap;
use std::collections::HashMap;
use vm::VM;
use std::io::Write;
use wasmi::*;
use elipticoin_api::ElipticoinAPI;
use std::ops::Deref;
use std::sync::{RwLock,Arc};


use rustler::{Env, Term, Encoder, NifResult};
use rustler::types::binary::{ Binary, OwnedBinary };
use rustler::types::map::{ MapIterator };
use rustler::resource::ResourceArc;


mod atoms {
    rustler_atoms! {
        atom ok;
    }
}

rustler_export_nifs! {
    "Elixir.VM",
    [
        ("open_db", 2, open_db),
        ("run", 5, run),
    ],
    Some(on_load)
}

pub trait DB {
    fn write(&self, key: &[u8], value: &[u8]);
    fn read(&self, key: &[u8]) -> Vec<u8>;
}

impl<'a> DB for std::sync::RwLockWriteGuard<'a, rocksdb::DB> {
    fn write(&self, key: &[u8], value: &[u8]) {
        self.put(key, value).expect("failed to write");
    }

    fn read(&self, key: &[u8]) -> Vec<u8> {
        match self.get(key) {
            Ok(Some(value)) => value.to_vec(),
            Ok(None) => vec![],
            Err(e) => panic!(e),
        }
    }
}

impl<'a> DB for std::sync::RwLockWriteGuard<'a, redis::Client> {
    fn write(&self, key: &[u8], value: &[u8]) {
        let con = self.get_connection().unwrap();
        let _: () = con.set(key, value).unwrap();
    }

    fn read(&self, key: &[u8]) -> Vec<u8> {
        let con = self.get_connection().unwrap();
        con.get(key).unwrap()
    }
}

struct RocksDBHandle {
    pub db: Arc<RwLock<rocksdb::DB>>,
}

impl Deref for RocksDBHandle {
    type Target = Arc<RwLock<rocksdb::DB>>;

    fn deref(&self) -> &Self::Target { &self.db }
}

struct RedisHandle {
    pub db: Arc<RwLock<redis::Client>>,
}

impl Deref for RedisHandle {
    type Target = Arc<RwLock<redis::Client>>;

    fn deref(&self) -> &Self::Target { &self.db }
}

struct DBHandle {
    pub db: Arc<RwLock<DB + std::marker::Sync + std::marker::Send>>,
}

impl Deref for DBHandle {
    type Target = Arc<RwLock<DB + std::marker::Sync + std::marker::Send>>;

    fn deref(&self) -> &Self::Target { &self.db }
}


fn on_load<'a>(env: Env<'a>, _load_info: Term<'a>) -> bool {
    resource_struct_init!(RocksDBHandle, env);
    resource_struct_init!(RedisHandle, env);
    resource_struct_init!(DBHandle, env);
    true
}

fn open_rocksdb<'a>(env: Env<'a>, path: &'a str) -> Term<'a> {
    let db: rocksdb::DB = rocksdb::DB::open_default(path).unwrap();

    (atoms::ok(), ResourceArc::new(RocksDBHandle{
        db: Arc::new(RwLock::new(db)),
    })).encode(env)
}

fn open_redis<'a>(env: Env<'a>, path: &'a str) -> Term<'a> {
    let client = redis::Client::open(path).expect("failed to connect to redis");
    (atoms::ok(), ResourceArc::new(RedisHandle{
        db: Arc::new(RwLock::new(client)),
    })).encode(env)
}

fn open_db<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let backend: &str = &try!(try!(args[0].decode::<Term>()).atom_to_string()).to_string();
    let options: &str = try!(args[1].decode());

    let resp = match backend {
        "rocksdb" => open_rocksdb(env, options),
        "redis" => open_redis(env, options),
        _ => panic!("unknown backend")
    };

    Ok(resp)
}

fn run<'a>(nif_env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let db_arc: ResourceArc<RedisHandle> = args[0].decode()?;
    let ref db = db_arc.deref().db.write().unwrap();
    let env_iter: MapIterator = try!(args[1].decode());
    let address: Binary = try!(args[2].decode());
    let contract_id: Binary = try!(args[3].decode());
    let rpc_binary: Binary = try!(args[4].decode());
    let rpc: Vec<Value> = from_slice(rpc_binary.as_slice()).unwrap();


    let con = db.get_connection().unwrap();
    let code: Vec<u8> = con.get([address, contract_id].concat().to_vec()).unwrap();
    // println!("Code: {:?}", code);
    // println!("^--^");
    let ref func = rpc[0].as_string().unwrap();
    let args_iter = rpc[1]
        .as_array()
        .unwrap();

    let mut env = HashMap::new();
    for (key, value) in env_iter {
        env.insert(
            try!(key.atom_to_string()),
            try!(value.decode::<Binary>()).as_slice()
        );
    }

    let module = ElipticoinAPI::new_module(&code);
    let mut vm = VM::new(db, &env, &module);

    let mut args = Vec::new();

    for arg in args_iter {
        if arg.is_number() {
            args.push(RuntimeValue::I32(arg.as_u64().unwrap() as i32));
        } else {
            let arg_pointer = vm.write_pointer(to_vec(arg).unwrap());
            args.push(RuntimeValue::I32(arg_pointer as i32));
        }
    }


    let pointer = vm.call(&func, &args);
    let output = vm.read_pointer(pointer);

    let mut binary = OwnedBinary::new(output.len()).unwrap();
    binary.as_mut_slice().write(&output).unwrap();
    Ok((atoms::ok(), binary.release(nif_env)).encode(nif_env))
}
