#[macro_use] extern crate rustler;
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


use rustler::{NifEnv, NifTerm, NifResult, NifEncoder};
use rustler::types::binary::{ NifBinary, OwnedNifBinary };


mod atoms {
    rustler_atoms! {
        atom ok;
    }
}

rustler_export_nifs! {
    "Elixir.VM",
    [("run", 3, run)],
    None
}


fn run<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let code: NifBinary = try!(args[0].decode());
    let func: &str = try!(args[1].decode());
    let arg: NifBinary = try!(args[2].decode());

    let db = DB::open_default("tmp/blockchain.db").unwrap();
    let module = ElipticoinAPI::new_module(code.to_vec());
    let mut vm = VM::new(&module, &db);

    let arg_pointer = vm.write_pointer(arg.to_vec());
    let pointer = vm.call(&func, arg_pointer);
    let output = vm.read_pointer(pointer);

    let mut binary = OwnedNifBinary::new(output.len()).unwrap();
    binary.as_mut_slice().write(&output).unwrap();
    Ok((atoms::ok(), binary.release(env)).encode(env))
}
