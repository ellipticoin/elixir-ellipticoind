#[macro_use]
extern crate lazy_static;
extern crate serde;
extern crate serde_cbor;
extern crate vm;

use serde_cbor::{from_slice, to_vec};
use std::env::args;
use std::{io, process, thread, time};
use vm::{Commands, Transaction};

lazy_static! {
    static ref COMMAND: String = {
        args().nth(1).unwrap()
    };
    static ref TRANSACTION_PROCESSING_TIME: u64 = {
        args().nth(3).unwrap().parse().unwrap()
    };
    static ref REDIS: redis::Client ={
        redis::Client::open(args().nth(2).unwrap().as_str()).unwrap()
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
        _ => exit(),
    }
    exit();
}

fn process_existing_block() {
    let conn = REDIS.get_connection().unwrap();

    for transaction in get_next_transaction(&conn, "block") {
        run_transaction(&conn, transaction);
    }
}

fn process_new_block() {
    let conn = REDIS.get_connection().unwrap();
    run_for(*TRANSACTION_PROCESSING_TIME, || {
        match get_next_transaction(&conn, "transactions::queued") {
            Some(transaction) => run_transaction(&conn, transaction),
            None => sleep_1_milli(),
        };
    })
}

fn sleep_1_milli() {
    thread::sleep(time::Duration::from_millis(1));
}

fn run_for<F: Fn()>(duration_u64: u64, function: F) {
    let start = time::Instant::now();
    let duration = time::Duration::from_millis(duration_u64);
    while start.elapsed() < duration {
        function();
    }
}

fn run_transaction(conn: &vm::Connection, transaction: vm::Transaction) {
    let result = vm::run_transaction(&transaction, conn);
    // println!("{:?}", result);
    save_result(&conn, transaction, result);
}

fn save_result(conn: &vm::Connection, transaction: Transaction, result: Vec<u8>) {
    let transaction_bytes = to_vec(&transaction).unwrap();
    let _: () = redis::pipe()
        .atomic()
        .cmd("LREM")
        .arg("transactions::processing")
        .arg(0)
        .arg(transaction_bytes.as_slice())
        .ignore()
        .cmd("RPUSH")
        .arg("transactions::done")
        .arg(transaction_bytes.as_slice())
        .ignore()
        .cmd("RPUSH")
        .arg("results")
        .arg(result)
        .ignore()
        .query(conn)
        .unwrap();
}

fn get_next_transaction(conn: &vm::Connection, source: &str) -> Option<Transaction> {
    let transaction_bytes: Vec<u8> = conn.rpoplpush(source, "transactions::processing").unwrap();

    if transaction_bytes.len() == 0 {
        println!("None");
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
                exit();
            }
            Err(error) => {
                panic!("{}", error);
            }
        }
    });
}

fn exit() {
    println!("");
    process::exit(0);
}
