#![feature(custom_attribute)]
#[macro_use] extern crate rustler;
#[macro_use] extern crate rustler_codegen;
#[macro_use] extern crate lazy_static;
extern crate rocksdb;
extern crate wasmi;
use rocksdb::DB;

mod elipticoin_api;
mod helpers;
mod vm;
use vm::VM;
use std::io::Write;
use wasmi::*;
use elipticoin_api::ElipticoinAPI;
use std::ops::Deref;
use std::sync::{RwLock,Arc};


use rustler::{NifEnv, NifTerm, NifResult, NifEncoder};
use rustler::types::binary::{ NifBinary, OwnedNifBinary };
use rustler::resource::ResourceArc;


mod atoms {
    rustler_atoms! {
        atom ok;
    }
}

rustler_export_nifs! {
    "Elixir.VM",
    [
        ("open_db", 1, open_db),
        ("run", 4, run),
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


fn on_load<'a>(env: NifEnv<'a>, _load_info: NifTerm<'a>) -> bool {
    resource_struct_init!(DBHandle, env);
    true
}

fn open_db<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let path: &str = try!(args[0].decode());
    let db: DB = DB::open_default(path).unwrap();

    let resp =
        (atoms::ok(), ResourceArc::new(DBHandle{
            db: Arc::new(RwLock::new(db)),
        })).encode(env);
    Ok(resp)
}

fn run<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let db_arc: ResourceArc<DBHandle> = args[0].decode()?;
    let db = db_arc.deref().db.write().unwrap();
    let code: NifBinary = try!(args[1].decode());
    let func: &str = try!(args[2].decode());
    let arg: NifBinary = try!(args[3].decode());

    let module = ElipticoinAPI::new_module(&code);
    let mut vm = VM::new(&module, &db);

    let arg_pointer = vm.write_pointer(arg.to_vec());
    let pointer = vm.call(&func, arg_pointer);
    let output = vm.read_pointer(pointer);

    let mut binary = OwnedNifBinary::new(output.len()).unwrap();
    binary.as_mut_slice().write(&output).unwrap();
    Ok((atoms::ok(), binary.release(env)).encode(env))
}
