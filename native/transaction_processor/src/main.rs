#[macro_use] extern crate lazy_static;
extern crate heck;
extern crate redis;
extern crate serde_cbor;
extern crate vm;

use std::collections::{
    BTreeMap,
    HashMap,
};
use serde_cbor::{
    to_vec,
    from_slice,
    Value,
};
use std::mem::transmute;
use std::io::Read;
use std::fs::File;
use heck::SnakeCase;
use vm::{
    EllipticoinAPI,
    RuntimeValue,
    VM,
    DB,
    Client,
};
use vm::Commands;



const BASE_CONTRACTS_PATH: &str = "../../base_contracts";
const USER_CONTRACTS_NAME: &str = "UserContracts";

lazy_static! {
    static ref SYSTEM_ADDRESS: Vec<u8> = vec![0;32];
}
lazy_static! {
    static ref SYSTEM_CONTRACTS: HashMap<&'static str, Vec<u8>> = {
        let system_contracts = vec!{
            "BaseApi",
            "BaseToken",
            USER_CONTRACTS_NAME,
        };
        system_contracts.iter().map(|&system_contract| {
            let filename = format!("{}.wasm", system_contract.clone().to_snake_case());
            let mut file = File::open(format!("{}/{}", BASE_CONTRACTS_PATH, filename)).unwrap();
            let mut buffer = Vec::new();
            file.read_to_end(&mut buffer).unwrap();
            (system_contract, buffer)
        }).collect()
    };
}

fn main() {
    let client: Client = vm::Client::open("redis://127.0.0.1/").unwrap();
    let conn = client.get_connection().unwrap();
    // for (name, code) in SYSTEM_CONTRACTS.iter() {
    //     println!("{:?} {}", name, code.len());
    // }
    loop {
        let transaction_bytes: Vec<u8> = conn.brpoplpush("transactions", "transactions_processing", 0).unwrap();
        let transaction: BTreeMap<String, Value> = from_slice(&transaction_bytes).unwrap();
        // println!("{:?}", transaction);
        let sender: Vec<u8> = transaction.get("sender").unwrap().as_bytes().unwrap().to_vec();
        let address: Vec<u8> = transaction.get("address").unwrap().as_bytes().unwrap().to_vec();
        let contract_name: &str = transaction.get("contract_name").unwrap().as_string().unwrap();
        let nonce: i64 = transaction.get("nonce").unwrap().as_i64().unwrap();
        let method: &str = transaction.get("method").unwrap().as_string().unwrap();
        let params_raw: Vec<Value> = transaction.get("params").unwrap().as_array().unwrap().to_vec();

        let mut env: HashMap<String, Vec<u8>> = HashMap::new();
        env.insert("sender".to_string(), sender.clone());
        env.insert("address".to_string(), address.clone());
        env.insert("contract_name".to_string(), contract_name.clone().as_bytes().to_vec());

        let nonce_bytes: [u8; 8] = unsafe { transmute(nonce) };
        let code = get_code(&conn, address, contract_name);
        let module = EllipticoinAPI::new_module(&code);
        let mut vm = VM::new(&conn, &env, &module);
        let params: Vec<RuntimeValue> = params_raw.iter().map(|param| {
            let param_vec = to_vec(param).unwrap();
            let param_pointer = vm.write_pointer(param_vec);
            RuntimeValue::I32(param_pointer as i32)
        }).collect();
        let pointer = vm.call(&method, &params);
        let output = vm.read_pointer(pointer);

        let mut message = vec![];
        message.extend(sender);
        message.extend(nonce_bytes.to_vec());
        message.extend(output);

        conn.publish::<&str, Vec<u8>, ()>("transactions", message).unwrap();
    }
}

fn get_code(conn: &vm::Connection, address: Vec<u8>, contract_name: &str) -> Vec<u8> {
    if address == SYSTEM_ADDRESS.to_vec() &&
        SYSTEM_CONTRACTS.contains_key(&contract_name) {
        SYSTEM_CONTRACTS.get(&contract_name).unwrap().to_vec()
    } else {
        let mut user_contract_addess = Vec::new();
        user_contract_addess.extend(SYSTEM_ADDRESS.to_vec());
        user_contract_addess.extend(USER_CONTRACTS_NAME.bytes());
        user_contract_addess.extend(contract_name.bytes());
        println!("getting {:?}", user_contract_addess);
        conn.get::<_, Vec<u8>>(user_contract_addess).unwrap().to_vec()
    }
}
