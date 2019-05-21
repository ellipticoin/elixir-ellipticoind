#![feature(result_map_or_else)]
#![feature(rustc_private)]
#[macro_use]
extern crate lazy_static;
extern crate serialize;
extern crate serde;
extern crate serde_cbor;
extern crate vm;

use serialize::hex::FromHex;
use serde_cbor::{from_slice, to_vec};
use std::env::args;
use std::{io, process, thread, time};
use vm::{Commands, Transaction, CompletedTransaction, Env};

lazy_static! {
    static ref COMMAND: String = {
        args().nth(2).unwrap()
    };
    static ref TRANSACTION_PROCESSING_TIME: u64 = {
        args().nth(4).unwrap().parse().unwrap()
    };
    static ref ENV: Vec<u8> = {
        args().nth(3).unwrap().from_hex().unwrap()
    };
    static ref REDIS: redis::Client ={
        redis::Client::open(args().nth(1).unwrap().as_str()).unwrap()
    };
}

fn main() {
    exit_on_close();
    match COMMAND.as_ref() {
        "process_new_block" => {
            process_new_block();
        }
        "process_existing_block" => {
            process_existing_block();
        }
        _ => (),
    }
}

fn process_existing_block() {
    let conn = REDIS.get_connection().unwrap();
    let env = from_slice::<Env>(&ENV).unwrap();
    let mut completed_transactions: Vec<CompletedTransaction> = Default::default();

    for transaction in get_next_transaction(&conn, "block") {
        let completed_transaction = run_transaction(&conn, &transaction, &env);
        completed_transactions.push(completed_transaction);
    }
    return_completed_transactions(completed_transactions);
}

fn process_new_block() {
    let env = from_slice::<Env>(&ENV).unwrap();
    let conn = REDIS.get_connection().unwrap();
    let mut completed_transactions: Vec<CompletedTransaction> = Default::default();
    run_for(*TRANSACTION_PROCESSING_TIME, || {
        match get_next_transaction(&conn, "transactions::queued") {
            Some(transaction) => {
                let completed_transaction = run_transaction(&conn, &transaction, &env);
                completed_transactions.push(completed_transaction);
            },
            None => sleep_1_milli(),
        };
    });
    return_completed_transactions(completed_transactions);
}

fn return_completed_transactions(completed_transactions: Vec<CompletedTransaction>) {
    let base64_encoded_results = completed_transactions
        .iter()
        .map(&to_vec)
        .map(|v| {v.unwrap()})
        .map(|completed_transaction_bytes| {
            base64::encode(&completed_transaction_bytes)
        })
        .collect::<Vec<String>>()
        .join(" ");
    println!("completed_transactions:{}", base64_encoded_results);
}

fn sleep_1_milli() {
    thread::sleep(time::Duration::from_millis(1));
}

fn run_for<F: FnMut()>(duration_u64: u64, mut function: F) {
    let start = time::Instant::now();
    let duration = time::Duration::from_millis(duration_u64);
    while start.elapsed() < duration {
        function();
    }
}

fn run_transaction(conn: &vm::Connection, transaction: &vm::Transaction, env: &Env) -> CompletedTransaction {

    let (return_code, return_value) = vm::run_transaction(transaction, conn, env);
    remove_from_processing(&conn, transaction);
    CompletedTransaction {
        contract_address: transaction.contract_address.clone(),
        contract_name: transaction.contract_name.clone(),
        sender: transaction.sender.clone(),
        nonce: transaction.nonce.clone(),
        function: transaction.function.clone(),
        arguments: transaction.arguments.clone(),
        return_value: return_value,
        return_code: return_code,
    }
}

fn remove_from_processing(conn: &vm::Connection, transaction: &Transaction) {
    let transaction_bytes = to_vec(&transaction).unwrap();
    conn.lrem::<_, _, ()>(
        "transactions::processing",
        0,
        transaction_bytes.as_slice()
        ).unwrap();
}

fn get_next_transaction(conn: &vm::Connection, source: &str) -> Option<Transaction> {
    let transaction_bytes: Vec<u8> = conn.rpoplpush(source, "transactions::processing").unwrap();

    if transaction_bytes.len() == 0 {
        None
    } else {
        Some(from_slice::<Transaction>(&transaction_bytes).expect("from_slice failed"))
    }
}

//
//  https://stackoverflow.com/a/39772976/1356670
// "When a process is exited (the port is closed) the spawned program / port should get an EOF on
// its STDIN. This is the "standard" way for the process to detect when the port has been closed:
// an end-of-file on STDIN."

fn exit_on_close() {
    thread::spawn(move || {
        let mut input = String::new();
        match io::stdin().read_line(&mut input) {
            Ok(_) => {
                process::exit(0);
            }
            Err(error) => {
                panic!("{}", error);
            }
        }
    });
}
