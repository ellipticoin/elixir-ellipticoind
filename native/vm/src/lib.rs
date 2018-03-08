#![feature(custom_attribute)]
#[macro_use] extern crate rustler;
#[macro_use] extern crate lazy_static;
extern crate rocksdb;
extern crate wasmi;
use rocksdb::DB;

mod elipticoin_api;
mod helpers;
mod vm;
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
use rustler::types::atom::{ Atom };
use rustler::resource::ResourceArc;


mod atoms {
    rustler_atoms! {
        atom ok;
        atom sender;
    }
}

rustler_export_nifs! {
    "Elixir.VM",
    [
        ("open_db", 1, open_db),
        ("run", 5, run),
    ],
    Some(on_load)
}
struct DBHandle {
    pub db: Arc<RwLock<DB>>,
}

impl Deref for DBHandle {
    type Target = Arc<RwLock<DB>>;

    fn deref(&self) -> &Self::Target { &self.db }
}


fn on_load<'a>(env: Env<'a>, _load_info: Term<'a>) -> bool {
    resource_struct_init!(DBHandle, env);
    true
}

fn open_db<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let path: &str = try!(args[0].decode());
    let db: DB = DB::open_default(path).unwrap();

    let resp =
        (atoms::ok(), ResourceArc::new(DBHandle{
            db: Arc::new(RwLock::new(db)),
        })).encode(env);
    Ok(resp)
}

fn run<'a>(nif_env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let db_arc: ResourceArc<DBHandle> = args[0].decode()?;
    let db = db_arc.deref().db.write().unwrap();
    let env_iter: MapIterator = try!(args[1].decode());
    let code: Binary = try!(args[2].decode());
    let func: &str = try!(args[3].decode());
    let arg: Binary = try!(args[4].decode());

    let mut env = HashMap::new();
    for (key, value) in env_iter {
        env.insert(
            try!(key.atom_to_string()),
            try!(value.decode::<Binary>()).as_slice()
        );
    }

    let module = ElipticoinAPI::new_module(&code);
    let mut vm = VM::new(&db, &env, &module);

    let arg_pointer = vm.write_pointer(arg.to_vec());
    let pointer = vm.call(&func, arg_pointer);
    let output = vm.read_pointer(pointer);

    let mut binary = OwnedBinary::new(output.len()).unwrap();
    binary.as_mut_slice().write(&output).unwrap();
    Ok((atoms::ok(), binary.release(nif_env)).encode(nif_env))
}
