#[macro_use]
extern crate rustler;
#[macro_use]
extern crate rustler_codegen;
#[macro_use]
extern crate lazy_static;
extern crate redis;
extern crate serde_cbor;
extern crate vm;

use rustler::dynamic::TermType;
use rustler::types::Binary;
use rustler::types::{Encoder, OwnedBinary};
use rustler::{Env, NifResult, Term};
use serde_cbor::Value;
use std::io::Write;
use vm::{run_transaction, Client, Transaction};

impl<'a> From<NifTransaction<'a>> for Transaction {
    fn from(nif_transaction: NifTransaction<'a>) -> Self {
        Transaction {
            contract_address: nif_transaction.contract_address.as_slice().to_vec(),
            contract_name: match nif_transaction.contract_name.atom_to_string() {
                Ok(value) => value,
                Err(_err) => panic!(),
            },
            code: nif_transaction.contract_code.as_slice().to_vec(),
            arguments: nif_transaction
                .arguments
                .iter()
                .map(&term_to_value)
                .collect(),
            function: match nif_transaction.function.atom_to_string() {
                Ok(value) => value,
                Err(_err) => panic!(),
            },
            sender: nif_transaction.contract_address.as_slice().to_vec(),
        }
    }
}
#[derive(NifMap)]
struct NifTransaction<'a> {
    contract_address: Binary<'a>,
    contract_name: Term<'a>,
    contract_code: Binary<'a>,
    arguments: Vec<Term<'a>>,
    function: Term<'a>,
    sender: Binary<'a>,
}

mod atoms {
    rustler_atoms! {
        atom ok;
        atom contract_name;
    }
}

rustler_export_nifs! {
    "Elixir.VM",
    [
        ("run", 2, run),
    ],
    None
}

fn term_to_value(term: &Term) -> Value {
    match term.get_type() {
        TermType::Binary => match term.decode::<Binary>() {
            Ok(value) => Value::Bytes(value.as_slice().to_vec()),
            Err(_err) => panic!(),
        },
        TermType::Number => match term.decode::<i64>() {
            Ok(value) => {
                if value > 0 {
                    Value::U64(value as u64)
                } else {
                    Value::I64(value)
                }
            }
            Err(_err) => panic!(),
        },
        TermType::Atom => match term.atom_to_string() {
            Ok(value) => Value::String(value),
            Err(_err) => panic!(),
        },
        _ => Value::Null,
    }
}

fn run<'a>(nif_env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let conn_string: &str = try!(args[0].decode());
    let transaction: Transaction = try!(args[1].decode::<NifTransaction>()).into();
    let client: Client = vm::Client::open(conn_string).unwrap();
    let conn = client.get_connection().unwrap();

    let output = run_transaction(&transaction, &conn);

    let mut binary = OwnedBinary::new(output.len()).unwrap();
    binary.as_mut_slice().write(&output).unwrap();
    Ok(binary.release(nif_env).encode(nif_env))
}
