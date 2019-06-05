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
use vm::{Open};
use std::io::BufRead;

lazy_static! {
    static ref REDIS: redis::Client ={
        redis::Client::open(args().nth(1).unwrap().as_str()).unwrap()
    };
    static ref ROCKSDB: vm::DB ={
        vm::DB::open_default(args().nth(2).expect("rocksdb").as_str()).expect("rocksdb2")
    };
    static ref ENV: Vec<u8> = {
        args().nth(4).unwrap().from_hex().unwrap()
    };
    static ref TRANSACTION_PROCESSING_TIME: u64 = {
        args().nth(5).unwrap().parse().unwrap()
    };
}

fn rocksdb() -> vm::DB {
    loop {
        match vm::DB::open_default(args().nth(1).unwrap().as_str()) {
            Err(_e) => (),
            Ok(db) => { return db }
        }
        thread::sleep(std::time::Duration::from_millis(500))
    };
}

fn main() {
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        match line
            .unwrap()
            .split(" ")
            .collect::<Vec<&str>>()
            .as_slice() {
        ["process_new_block", env_bytes, transaction_processing_time] => {
            let env = from_slice::<Env>(&base64::decode(env_bytes).unwrap()).unwrap();
            process_new_block(&env, transaction_processing_time.parse().unwrap());
        }
        ["process_existing_block", env_bytes] => {
            let env = from_slice::<Env>(&base64::decode(env_bytes).expect("env")).expect("env2");
            process_existing_block(&env);
        }
        _ => (),
            }
    }
}

fn process_existing_block(env: &Env) {
    let redis = REDIS.get_connection().unwrap();
    let mut execution_order = 0;
    let mut completed_transactions: Vec<CompletedTransaction> = Default::default();

    for transaction in get_next_transaction(&redis, "block") {
        let completed_transaction = run_transaction(&redis, &ROCKSDB, &transaction, &env, execution_order);
        completed_transactions.push(completed_transaction);
        execution_order += 1;
    }
    return_completed_transactions(completed_transactions);
}

fn process_new_block(env: &Env, transaction_processing_time: u64) {
    let mut execution_order = 0;
    let redis = REDIS.get_connection().unwrap();
    let mut completed_transactions: Vec<CompletedTransaction> = Default::default();
    run_for(transaction_processing_time, || {
        match get_next_transaction(&redis, "transactions::queued") {
            Some(transaction) => {
                let completed_transaction = run_transaction(&redis, &ROCKSDB, &transaction, &env, execution_order);
                completed_transactions.push(completed_transaction);
                execution_order += 1;
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

fn run_transaction(redis: &vm::Connection, rocksdb: &vm::DB, transaction: &vm::Transaction, env: &Env, execution_order: u64) -> CompletedTransaction {

    let (return_code, return_value) = vm::run_transaction(transaction, redis, rocksdb, env);
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
        execution_order: execution_order,
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
