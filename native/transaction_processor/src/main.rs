#![feature(mpsc_select)]
extern crate redis;
extern crate vm;

use mpsc::channel;
use std::sync::mpsc;
use std::sync::Arc;
use std::{thread, time, process, io};


use vm::{
    run_transaction, transaction_from_slice, Client, Commands, ControlFlow, PubSubCommands,
    Transaction,
};

// Copied from:
// https://github.com/tkrs/rust-redis-pubsub-example/blob/master/src/main.rs#L8

trait AppState {
    fn client(&self) -> &Arc<Client>;
}

struct Ctx {
    pub client: Arc<Client>,
}

impl Ctx {
    fn new() -> Ctx {
        let client = Client::open("redis://localhost/").unwrap();
        Ctx {
            client: Arc::new(client),
        }
    }
}

impl AppState for Ctx {
    fn client(&self) -> &Arc<Client> {
        &self.client
    }
}

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

fn main() {
    exit_on_close();
    let ctx = Ctx::new();
    let client = Arc::clone(ctx.client());
    let mut conn = client.get_connection().unwrap();
    conn
        .subscribe::<_, _, ()>(&["transaction_processor"], |message| {
            let payload: String = message.get_payload().unwrap();
            let command_and_args = payload.split(" ").collect::<Vec<_>>();
            match command_and_args.as_slice() {
                ["proccess_transactions", duration] => {
                    let conn = client.get_connection().unwrap();
                    proccess_transactions(&conn, duration.parse().unwrap());
                    ControlFlow::Continue
                },
                command => panic!("Invalid command!: {:?}", command),
            }
        }).unwrap();


    // loop {
        // start_consumer.recv().unwrap();
        // println!("waiting for start");
        // wait_for_start(&ctx);
        // println!("got start");
        // let mut conn = client.get_connection().unwrap();
        // let (stop_producer, stop_consumer) = channel();
        // thread::spawn(move || {
        //     println!("waiting for stop");
        //     let _: () = conn
        //         .subscribe::<_, _, ()>(&["transaction_processor"], |message| {
        //             let command: String = message.get_payload().unwrap();
        //             match command.as_ref() {
        //                 "stop" => {
        //                     println!("sending stop!");
        //                     stop_producer.send(()).unwrap();
        //                     ControlFlow::Break(())
        //                 }
        //                 command => panic!("Unkown command {}", command),
        //             }
        //         }).unwrap();
        //         println!("stopped listening for stop");
        // });

        // loop {
            // let (continue_producer, continue_consumer) = channel();
            // let client = Arc::clone(ctx.client());
            // let handle = thread::spawn(move || {
            //     let conn = client.get_connection().unwrap();
            //     proccess_transactions(&conn);
            //     continue_producer.send(()).unwrap();
            // });
            // select! {
            //     _ = continue_consumer.recv() => {
            //         handle.join().unwrap();
            //     },
            //     _ = stop_consumer.recv() => {
            //         println!("got stop");
            //         continue_consumer.recv().unwrap();
            //         break;
            //     }
            // }
            // let ten_millis = time::Duration::from_millis(1);
            // thread::sleep(ten_millis);
        // }
    // }
}

fn proccess_transactions(conn: &vm::Connection, duration: u32) {
    let transaction_queue_size: u32 = conn.llen("transactions::queued").unwrap();
    if transaction_queue_size > 0 {
        let transaction_bytes: Vec<u8> = conn
            .rpoplpush("transactions::queued", "transactions::processing")
            .unwrap();
        let transaction: Transaction = transaction_from_slice(&transaction_bytes);

        let output = run_transaction(&transaction, conn);

        let mut transaction_result: Vec<u8> = Vec::new();
        transaction_result.extend(transaction.env.get("sender").unwrap().to_vec());

        transaction_result.extend(output);
        let _: () = vm::pipe()
            .atomic()
            .cmd("LPOP")
            .arg("transactions::processing")
            .ignore()
            .cmd("RPUSH")
            .arg("transactions::done")
            .arg(transaction_result)
            .ignore()
            .query(conn)
            .unwrap();
    }
}
