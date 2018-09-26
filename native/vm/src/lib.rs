#![feature(
    custom_attribute,
)]
#[macro_use] extern crate rustler;
#[macro_use] extern crate lazy_static;
extern crate sha3;
extern crate redis;
extern crate rocksdb;
extern crate wasmi;
extern crate serde_cbor;

mod ellipticoin_api;
mod helpers;
mod vm;

use serde_cbor::{to_vec, Value};
use redis::Commands;
use std::collections::HashMap;
use vm::VM;
use std::io::Write;
use wasmi::*;
use ellipticoin_api::ElipticoinAPI;
use std::ops::Deref;
use std::sync::{RwLock,Arc};
use db::redis::RedisHandle;
use sha3::{Digest, Sha3_256};


use rustler::{Env, Term, Encoder, NifResult};
use rustler::types::binary::{ Binary, OwnedBinary };
use rustler::types::map::{ MapIterator };
use rustler::types::list::{ ListIterator };
use rustler::resource::ResourceArc;

mod db;
use db::{DB};

mod atoms {
    rustler_atoms! {
        atom ok;
    }
}

rustler_export_nifs! {
    "Elixir.VM",
    [
        ("open_db", 2, open_db),
        ("run", 6, run),
        ("current_block_hash", 1, current_block_hash),
    ],
    Some(on_load)
}


fn on_load<'a>(env: Env<'a>, _load_info: Term<'a>) -> bool {
    resource_struct_init!(RedisHandle, env);
    true
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
    let method = try!(try!(args[4].decode::<Term>()).atom_to_string());
    let params_iter: ListIterator = try!(args[5].decode());

    let con = db.get_connection().unwrap();
    let code: Vec<u8> = con.get([address, contract_id].concat().to_vec()).unwrap();
    let mut env = HashMap::new();
    for (key, value) in env_iter {
        env.insert(
            try!(key.atom_to_string()),
            try!(value.decode::<Binary>()).as_slice()
        );
    }

    let module = ElipticoinAPI::new_module(&code);
    let mut vm = VM::new(db, &env, &module);

    let mut params = Vec::new();

    for param in params_iter {
        if param.is_number() {
            let param_u32: u32 = try!(param.decode());
            // params.push(RuntimeValue::I32(param_u32 as i32));
            let param = to_vec(&Value::U64(param_u32 as u64)).unwrap();

            let arg_pointer = vm.write_pointer(param);
            params.push(RuntimeValue::I32(arg_pointer as i32));
        } else {
            let param_binary: Binary = try!(param.decode());
            let param = to_vec(&Value::Bytes(param_binary.to_vec())).unwrap();
            let arg_pointer = vm.write_pointer(param);
            params.push(RuntimeValue::I32(arg_pointer as i32));
        }
    }

    let pointer = vm.call(&method, &params);
    let output = vm.read_pointer(pointer);

    let mut binary = OwnedBinary::new(output.len()).unwrap();
    binary.as_mut_slice().write(&output).unwrap();
    Ok((atoms::ok(), binary.release(nif_env)).encode(nif_env))
}

fn current_block_hash<'a>(nif_env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let db_arc: ResourceArc<RedisHandle> = args[0].decode()?;
    let ref db = db_arc.deref().db.write().unwrap();
    let block_data = db.get_block_data();
    let mut hasher = Sha3_256::default();
    hasher.input(&block_data);
    let block_hash = hasher.result();

    let mut binary = OwnedBinary::new(block_hash.len()).unwrap();
    binary.as_mut_slice().write(&block_hash).unwrap();
    Ok((binary.release(nif_env)).encode(nif_env))
}
