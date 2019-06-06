#![feature(result_map_or_else)]
#![feature(rustc_private)]
#[macro_use]
extern crate lazy_static;
extern crate serialize;
extern crate serde;
extern crate rocksdb;
extern crate serde_cbor;
extern crate vm;

use serialize::hex::FromHex;
use serde_cbor::{from_slice, to_vec};
use std::env::args;
use std::{io, thread, time};
use vm::{Commands, Transaction, CompletedTransaction, Env};
use vm::{Open};
use std::io::BufRead;
use rocksdb::ops::Put;

lazy_static! {
    static ref REDIS: redis::Client ={
        redis::Client::open(args().nth(1).unwrap().as_str()).unwrap()
    };
    static ref ROCKSDB_PATH: String = {
        args().nth(2).expect("rocksdb").to_string()
    };
    static ref ENV: Vec<u8> = {
        args().nth(4).unwrap().from_hex().unwrap()
    };
    static ref TRANSACTION_PROCESSING_TIME: u64 = {
        args().nth(5).unwrap().parse().unwrap()
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
        ["process_new_block", env_encoded, transaction_processing_time] => {
            let env = from_slice::<Env>(&base64::decode(env_encoded).unwrap()).unwrap();
            process_new_block(&env, transaction_processing_time.parse().unwrap());
        }
        ["process_existing_block", env_encoded, transactions_encoded] => {
            let env = from_slice::<Env>(&base64::decode(env_encoded).unwrap()).unwrap();
            let transactions = from_slice::<Vec<Transaction>>(&base64::decode(transactions_encoded).unwrap()).unwrap();
            process_existing_block(&env, &transactions);
        }
        ["set_storage", block_number, key_encoded, value_encoded] => {
            set_storage(
                block_number.parse().unwrap(),
                &base64::decode(key_encoded).unwrap(),
                &base64::decode(value_encoded).unwrap(),

                );
        },
        _ => (),
            }
    }
}

fn process_existing_block(env: &Env, transactions: &Vec<Transaction>) {
    let redis = REDIS.get_connection().unwrap();
    let rocksdb = vm::DB::open_default(ROCKSDB_PATH.as_str()).unwrap();
    let mut execution_order = 0;
    let mut completed_transactions: Vec<CompletedTransaction> = Default::default();

    for transaction in transactions {
        let completed_transaction = run_transaction(&redis, &rocksdb, &transaction, &env, execution_order);
        completed_transactions.push(completed_transaction);
        execution_order += 1;
    }
    return_completed_transactions(completed_transactions);
}

fn process_new_block(env: &Env, transaction_processing_time: u64) {
    let mut execution_order = 0;
    let redis = REDIS.get_connection().unwrap();
    let rocksdb = vm::DB::open_default(ROCKSDB_PATH.as_str()).unwrap();
    let mut completed_transactions: Vec<CompletedTransaction> = Default::default();
    run_for(transaction_processing_time, || {
        match get_next_transaction(&redis, "transactions::queued") {
            Some(transaction) => {
                let completed_transaction = run_transaction(&redis, &rocksdb, &transaction, &env, execution_order);
                completed_transactions.push(completed_transaction);
                execution_order += 1;
            },
            None => sleep_1_milli(),
        };
    });
    return_completed_transactions(completed_transactions);
}

fn hash_key(block_number: u64, key: &[u8]) -> Vec<u8> {
    [u64_to_vec(block_number), key.to_vec()].concat()
}
fn u64_to_vec(n: u64) -> Vec<u8> {
    return unsafe { std::intrinsics::transmute::<u64, [u8; 8]>(n) }.to_vec();
}
fn set_storage(block_number: u64, key: &[u8], value: &[u8]) {
    let rocksdb = vm::DB::open_default(ROCKSDB_PATH.as_str()).unwrap();
    rocksdb.put(hash_key(block_number, key), value).unwrap();
    println!("{}", base64::encode(&to_vec(&serde_cbor::Value::String("ok".to_string())).unwrap()));
}

fn return_completed_transactions(completed_transactions: Vec<CompletedTransaction>) {
    // println!("{}", &to_vec(&completed_transactions).unwrap().len());
    println!("{}", base64::encode(&to_vec(&completed_transactions).unwrap()));
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
