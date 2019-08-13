#![feature(result_map_or_else)]
#![feature(rustc_private)]
#[macro_use]
extern crate lazy_static;
extern crate serialize;
extern crate serde;
extern crate rocksdb;
extern crate serde_cbor;
extern crate vm;
extern crate libc;

use serde_cbor::{from_slice, to_vec};
use std::env::args;
use std::{io, thread, time};
use vm::{Commands, Changeset, Transaction, CompletedTransaction, Env};
use vm::{Open};
use std::io::BufRead;
use std::collections::HashMap;

lazy_static! {
    static ref COMMAND: String ={
        args().nth(1).unwrap()
    };
    static ref REDIS: redis::Client ={
        redis::Client::open(args().nth(2).unwrap().as_str()).unwrap()
    };
    static ref ROCKSDB_PATH: String = {
        args().nth(3).expect("rocksdb").to_string()
    };
    static ref ENV: Vec<u8> = {
        base64::decode(&args().nth(4).unwrap()).unwrap()
    };
    static ref TRANSACTION_PROCESSING_TIME: u64 = {
        args().nth(5).unwrap().parse().unwrap()
    };
}

fn main() {
    // Fixes https://github.com/rust-lang/rust/issues/46016
    unsafe {
        libc::signal(libc::SIGPIPE, libc::SIG_DFL);
    }

    match (*COMMAND).as_str() {
        "process_new_block" => process_new_block(),
        "process_existing_block" => process_existing_block(),
        _ => (),
    }
}

fn process_existing_block() {
    let mut transactions_encoded = String::new();
    let stdin = io::stdin();
    stdin.lock().read_line(&mut transactions_encoded).expect("Could not read line");
    let transactions = from_slice::<Vec<Transaction>>(&base64::decode(&transactions_encoded.trim_end_matches("\n")).unwrap()).unwrap();
    let mut memory_changeset = HashMap::new();
    let mut storage_changeset = HashMap::new();
    let redis = REDIS.get_connection().unwrap();
    let rocksdb = vm::ReadOnlyDB::open_default(ROCKSDB_PATH.as_str()).unwrap();
    let env = from_slice::<Env>(&ENV).unwrap();
    let mut completed_transactions: Vec<CompletedTransaction> = Default::default();

    for transaction in transactions {
        let completed_transaction = run_transaction(&redis, &rocksdb, &transaction, &env, &mut memory_changeset, &mut storage_changeset);
        completed_transactions.push(completed_transaction);
    }
    completed_transactions.reverse();
    return_completed_transactions(completed_transactions, memory_changeset, storage_changeset);
}

fn process_new_block() {
    let mut memory_changeset = HashMap::new();
    let mut storage_changeset = HashMap::new();
    let redis = REDIS.get_connection().unwrap();
    let rocksdb = vm::ReadOnlyDB::open_default(ROCKSDB_PATH.as_str()).unwrap();
    let env = from_slice::<Env>(&ENV).unwrap();
    let mut completed_transactions: Vec<CompletedTransaction> = Default::default();
    run_for(*TRANSACTION_PROCESSING_TIME, || {
        match get_next_transaction(&redis, "transactions::queued") {
            Some(transaction) => {
                let completed_transaction = run_transaction(&redis, &rocksdb, &transaction, &env, &mut memory_changeset, &mut storage_changeset);
                completed_transactions.push(completed_transaction);
            },
            None => sleep_1_milli(),
        };
    });
    return_completed_transactions(completed_transactions, memory_changeset, storage_changeset);
}

fn return_completed_transactions(completed_transactions: Vec<CompletedTransaction>, memory_changeset: Changeset, storage_changeset: Changeset) {
    let memory_changeset_bytes: serde_cbor::Value  = 
        serde_cbor::Value::Map(memory_changeset.iter()
         .map(|(key, value)| (
                 serde_cbor::Value::Bytes(key.to_vec()),
                 serde_cbor::Value::Bytes(value.to_vec())
        )).collect());
    let storage_changeset_bytes: serde_cbor::Value  = 
        serde_cbor::Value::Map(storage_changeset.iter()
         .map(|(key, value)| (
                 serde_cbor::Value::Bytes(key.to_vec()),
                 serde_cbor::Value::Bytes(value.to_vec())
        )).collect());
    println!(
        "{} {} {}",
        base64::encode(&to_vec(&completed_transactions).unwrap()),
        base64::encode(&to_vec(&memory_changeset_bytes).unwrap()),
        base64::encode(&to_vec(&storage_changeset_bytes).unwrap()),
    );
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

fn run_transaction(redis: &vm::Connection, rocksdb: &vm::ReadOnlyDB, transaction: &vm::Transaction, env: &Env, memory_changeset: &mut Changeset, storage_changeset: &mut Changeset) -> CompletedTransaction {

    let (return_code, return_value) = vm::run_transaction(transaction, redis, rocksdb, env, memory_changeset, storage_changeset);
    remove_from_processing(&redis, transaction);
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

fn remove_from_processing(redis: &vm::Connection, transaction: &Transaction) {
    let transaction_bytes = to_vec(&transaction).unwrap();
    redis.lrem::<_, _, ()>(
        "transactions::processing",
        0,
        transaction_bytes.as_slice()
        ).unwrap();
}

fn get_next_transaction(redis: &vm::Connection, source: &str) -> Option<Transaction> {
    let transaction_bytes: Vec<u8> = redis.rpoplpush(source, "transactions::processing").unwrap();

    if transaction_bytes.len() == 0 {
        None
    } else {
        Some(from_slice::<Transaction>(&transaction_bytes).unwrap())
    }
}
