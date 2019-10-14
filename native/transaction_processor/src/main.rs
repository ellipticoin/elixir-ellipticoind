#![feature(result_map_or_else)]
#![feature(rustc_private)]
#[macro_use]
extern crate lazy_static;
extern crate libc;
extern crate rocksdb;
extern crate serde;
extern crate serde_cbor;
extern crate serialize;
extern crate vm;

use serde_cbor::{from_slice, to_vec};
use std::collections::HashMap;
use std::env::args;
use std::io::BufRead;
use std::{io, thread, time, process};
use vm::Open;
use vm::{Changeset, Commands, CompletedTransaction, Env, Transaction, Memory, Storage};
mod system_contracts;

lazy_static! {
    static ref COMMAND: String = { args().nth(1).unwrap() };
    static ref REDIS_URL: String =
        { args().nth(2).unwrap() };
    static ref ROCKSDB_PATH: String = { args().nth(3).expect("rocksdb").to_string() };
    static ref ENV: Vec<u8> = { base64::decode(&args().nth(4).unwrap()).unwrap() };
    static ref TRANSACTION_PROCESSING_TIME: u64 = { args().nth(5).unwrap().parse().unwrap() };
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
    stdin
        .lock()
        .read_line(&mut transactions_encoded)
        .expect("Could not read line");
    let transactions = from_slice::<Vec<Transaction>>(
        &base64::decode(&transactions_encoded.trim_end_matches("\n")).unwrap(),
    )
    .unwrap();
    exit_on_close();
    let mut memory_changeset = HashMap::new();
    let mut storage_changeset = HashMap::new();
    let mut completed_transactions: Vec<CompletedTransaction> = Default::default();

    for transaction in transactions {
        let redis_client = redis::Client::open((*REDIS_URL).as_str()).unwrap();
        let env = from_slice::<Env>(&ENV).unwrap();
        let completed_transaction = run_transaction(
            redis_client,
            vm::ReadOnlyDB::open_default(ROCKSDB_PATH.as_str()).unwrap(),
            &transaction,
            env,
            &mut memory_changeset,
            &mut storage_changeset
        );
        completed_transactions.push(completed_transaction);
    }
    return_completed_transactions(completed_transactions, memory_changeset, storage_changeset);
}

fn process_new_block() {
    exit_on_close();
    let redis_client = redis::Client::open((*REDIS_URL).as_str()).unwrap();
    let redis = redis_client.get_connection().unwrap();
    let mut memory_changeset = HashMap::new();
    let mut storage_changeset = HashMap::new();
    let mut completed_transactions: Vec<CompletedTransaction> = Default::default();
    run_for(*TRANSACTION_PROCESSING_TIME, || {
        match get_next_transaction(&redis, "transactions::queued") {
            Some(transaction) => {
                let env = from_slice::<Env>(&ENV).unwrap();
                let rocksdb = vm::ReadOnlyDB::open_default(ROCKSDB_PATH.as_str()).unwrap();
                let redis_client = redis::Client::open((*REDIS_URL).as_str()).unwrap();
                let completed_transaction = run_transaction(
                    redis_client,
                    rocksdb,
                    &transaction,
                    env,
                    &mut memory_changeset,
                    &mut storage_changeset,
                );
                completed_transactions.push(completed_transaction);
            }
            None => sleep_1_milli(),
        };
    });
    return_completed_transactions(completed_transactions, memory_changeset, storage_changeset);
}

fn return_completed_transactions(
    completed_transactions: Vec<CompletedTransaction>,
    memory_changeset: Changeset,
    storage_changeset: Changeset,
) {
    let memory_changeset_bytes: serde_cbor::Value = serde_cbor::Value::Map(
        memory_changeset
            .iter()
            .map(|(key, value)| {
                (
                    serde_cbor::Value::Bytes(key.to_vec()),
                    serde_cbor::Value::Bytes(value.to_vec()),
                )
            })
            .collect(),
    );
    let storage_changeset_bytes: serde_cbor::Value = serde_cbor::Value::Map(
        storage_changeset
            .iter()
            .map(|(key, value)| {
                (
                    serde_cbor::Value::Bytes(key.to_vec()),
                    serde_cbor::Value::Bytes(value.to_vec()),
                )
            })
            .collect(),
    );
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

fn run_transaction(
    redis: vm::Client,
    rocksdb: vm::ReadOnlyDB,
    transaction: &vm::Transaction,
    env: Env,
    memory_changeset: &mut Changeset,
    storage_changeset: &mut Changeset,
) -> CompletedTransaction {
    let (transaction_memory_changeset, transaction_storage_changeset, result) = if system_contracts::is_system_contract(&transaction) {
        let memory = Memory::new(redis.get_connection().unwrap(), memory_changeset.clone());
        let storage = Storage::new(redis.get_connection().unwrap(), rocksdb, storage_changeset.clone());
        system_contracts::run(
            transaction,
            memory,
            storage,
            env,
        )
    } else {
        let memory = Memory::new(redis.get_connection().unwrap(), memory_changeset.clone());
        let storage = Storage::new(redis.get_connection().unwrap(), rocksdb, storage_changeset.clone());
        let (memory_changeset, storage_changeset, (result, gas_left)) =
            transaction.run(memory, storage, env);
        let gas_used = transaction.gas_limit - gas_left.expect("no gas left") as u64;

        let env = from_slice::<Env>(&ENV).unwrap();
        let (gas_memory_changeset, _, _) = system_contracts::transfer(
            transaction,
            &redis,
            vm::ReadOnlyDB::open_default(ROCKSDB_PATH.as_str())     .unwrap(),
            memory_changeset,
            Changeset::new(),
            &env,
            gas_used as u32,
            transaction.sender.clone(),
            env.block_winner.clone()
        );
        (gas_memory_changeset, storage_changeset, result)
    };
    remove_from_processing(redis.get_connection().unwrap(), transaction);
    memory_changeset.extend(transaction_memory_changeset);
    storage_changeset.extend(transaction_storage_changeset);
    transaction.complete(result)
}

fn remove_from_processing(redis: vm::Connection, transaction: &Transaction) {
    let transaction_bytes = to_vec(&transaction).unwrap();
    redis
        .lrem::<_, _, ()>("transactions::processing", 0, transaction_bytes.as_slice())
        .unwrap();
}

fn get_next_transaction(redis: &vm::Connection, source: &str) -> Option<Transaction> {
    let transaction_bytes: Vec<u8> = redis.rpoplpush(source, "transactions::processing").unwrap();

    if transaction_bytes.len() == 0 {
        None
    } else {
        Some(
            from_slice::<Transaction>(&transaction_bytes)
                .expect("failed to load transaction_bytes"),
        )
    }
}
//
//  https://stackoverflow.com/a/39772976/1356670
// "When a process is exited (the port is closed) the spawned program / port should get an EOF on
// its STDIN. This is the "standard" way for the process to detect when the port has been closed:
// an end-of-file on STDIN."

fn exit_on_close() {
    thread::spawn(move || {
        let mut buffer = String::new();
        let bytes = io::stdin().read_line(&mut buffer).unwrap();
        if bytes == 0 {
            process::exit(0);
        }
    });
}
