extern crate redis;
extern crate vm;

use vm::{run_transaction, transaction_from_slice, Client, Commands, Transaction};

fn main() {
    let client: Client = vm::Client::open("redis://127.0.0.1/").unwrap();
    let conn = client.get_connection().unwrap();
    loop {
        let transaction_bytes: Vec<u8> = conn
            .brpoplpush("transactions::queued", "transactions::processing", 0)
            .unwrap();
        let transaction: Transaction = transaction_from_slice(&transaction_bytes);

        let output = run_transaction(&transaction, &conn);

        // let nonce_bytes: [u8; 8] = unsafe { transmute(transaction.nonce.unwrap_or(0)) };
        let mut transaction_result: Vec<u8> = Vec::new();
        transaction_result.extend(transaction.env.get("sender").unwrap().to_vec());

        // transaction_result.extend(nonce_bytes.to_vec());
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
            .query(&conn)
            .unwrap();

        //
        // conn.publish::<&str, Vec<u8>, ()>("transactions", message).unwrap();
    }
}
