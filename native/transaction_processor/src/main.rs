extern crate redis;
extern crate serde_cbor;
extern crate serde_derive;
extern crate vm;

use serde_cbor::from_slice;
use std::env;
use std::{io, process, thread, time};

use vm::{run_transaction, Commands, ControlFlow, PubSubCommands, Transaction};

fn main() {
    exit_on_close();
    let args: Vec<String> = env::args().collect();
    let client = redis::Client::open(args[1].as_str()).unwrap();
    let mut conn = client.get_connection().unwrap();
    conn.subscribe::<_, _, ()>(&["transaction_processor"], |message| {
        let payload: String = message.get_payload().unwrap();
        let command_and_args = payload.split(" ").collect::<Vec<_>>();
        match command_and_args.as_slice() {
            ["proccess_transactions", duration] => {
                let conn = client.get_connection().unwrap();
                proccess_transactions(&conn, duration.parse().unwrap());
                ControlFlow::Continue
            }
            _ => ControlFlow::Continue,
        }
    })
    .unwrap();
}

fn proccess_transactions(conn: &vm::Connection, duration_u64: u64) {
    let start = time::Instant::now();
    let duration = time::Duration::from_millis(duration_u64);

    while start.elapsed() < duration {
        match get_next_transaction(conn) {
            Some(transaction) => {
                run_transaction(&transaction, conn);
                ()
            }
            None => thread::sleep(time::Duration::from_millis(10)),
        };
    }
    let _: () = conn.publish("transaction_processor", "done").unwrap();
}

fn get_next_transaction(conn: &vm::Connection) -> Option<Transaction> {
    let transaction_bytes: Vec<u8> = conn
        .rpoplpush("transactions::queued", "transactions::processing")
        .unwrap();

    if transaction_bytes.len() == 0 {
        None
    } else {
        Some(from_slice::<Transaction>(&transaction_bytes).unwrap())
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
