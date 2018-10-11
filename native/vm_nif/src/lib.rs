#[macro_use] extern crate rustler;
#[macro_use] extern crate lazy_static;
extern crate vm;
extern crate redis;

use rustler::{Env, Term, NifResult};
use rustler::types::{
    Encoder,
    OwnedBinary,
    Binary,
};
use std::io::Write;
use vm::{
    Client,
    transaction_from_slice,
    run_transaction,
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
    let transaction_binary: Binary = try!(args[1].decode());
    let client: Client = vm::Client::open(conn_string).unwrap();
    let conn = client.get_connection().unwrap();
    let transaction = transaction_from_slice(&transaction_binary.to_vec());
    let output = run_transaction(&transaction, &conn);

    let mut binary = OwnedBinary::new(output.len()).unwrap();
    binary.as_mut_slice().write(&output).unwrap();
    Ok((atoms::ok(), binary.release(nif_env)).encode(nif_env))
}
