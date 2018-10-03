#[macro_use] extern crate rustler;
#[macro_use] extern crate rustler_codegen;
#[macro_use] extern crate lazy_static;
extern crate vm;
extern crate serde_cbor;
extern crate redis;

use redis::{
    Connection,
};
use rustler::{Env, Term, NifResult};
use rustler::types::{
    MapIterator,
    Encoder,
    OwnedBinary,
    Binary,
    ListIterator,
};
use std::io::Write;
use std::sync::{RwLockWriteGuard,RwLock,Arc};
use std::ops::Deref;
use std::collections::HashMap;
use serde_cbor::{
    to_vec,
    Value,
};
use vm::{
    EllipticoinAPI,
    RuntimeValue,
    VM,
    Client,
    Commands,
};

mod atoms {
    rustler_atoms! {
        atom ok;
    }
}

rustler_export_nifs! {
    "Elixir.VM",
    [
        ("run", 2, run),
    ],
    None
}


fn run<'a>(nif_env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let conn_string: &str = try!(args[0].decode());
    let transaction: Binary = try!(args[1].decode());
    let client: Client = vm::Client::open(conn_string).unwrap();
    let conn = client.get_connection().unwrap();

    let output = vec![0,0,0,0];

    let mut binary = OwnedBinary::new(output.len()).unwrap();
    binary.as_mut_slice().write(&output).unwrap();
    Ok((atoms::ok(), binary.release(nif_env)).encode(nif_env))
}
