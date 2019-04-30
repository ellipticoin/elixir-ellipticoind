use ellipticoin_api::EllipticoinAPI;
use heck::SnakeCase;
use redis::Connection;
use serde_cbor::Value;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::File;
use std::mem::transmute;
use std::io::Read;
use env::Env;

use vm::VM;
const BASE_CONTRACTS_PATH: &str = "base_contracts";
const USER_CONTRACTS_NAME: &str = "UserContracts";

lazy_static! {
    static ref SYSTEM_ADDRESS: Vec<u8> = vec![0; 32];
}
lazy_static! {
    static ref SYSTEM_CONTRACTS: HashMap<&'static str, Vec<u8>> = {
        let system_contracts = vec!["BaseApi", "BaseToken", USER_CONTRACTS_NAME];
        system_contracts
            .iter()
            .map(|&system_contract| {
                let filename = format!("{}.wasm", system_contract.clone().to_snake_case());
                let mut file = File::open(format!("{}/{}", BASE_CONTRACTS_PATH, filename)).unwrap();
                let mut buffer = Vec::new();
                file.read_to_end(&mut buffer).unwrap();
                (system_contract, buffer)
            })
            .collect()
    };
}
use serde_cbor::{to_vec};
pub use wasmi::RuntimeValue;


#[derive(Deserialize, Serialize, Debug)]
pub struct Transaction {
    #[serde(with = "serde_bytes")]
    pub contract_address: Vec<u8>,
    pub contract_name: String,
    #[serde(with = "serde_bytes")]
    pub code: Vec<u8>,
    #[serde(with = "serde_bytes")]
    pub sender: Vec<u8>,
    pub nonce: u64,
    pub function: String,
    pub arguments: Vec<Value>,
}

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct CompletedTransaction {
    #[serde(with = "serde_bytes")]
    pub contract_address: Vec<u8>,
    pub contract_name: String,
    #[serde(with = "serde_bytes")]
    pub sender: Vec<u8>,
    pub function: String,
    pub arguments: Vec<Value>,
    pub return_value: Value,
    pub return_code: u32,
}

pub fn run_transaction(transaction: &Transaction, db: &Connection, env: &Env) -> (u32, Value) {
    let module = EllipticoinAPI::new_module(&transaction.code);

    let mut vm = VM::new(db, &env, transaction, &module);
    let arguments: Vec<RuntimeValue> = transaction
        .arguments
        .iter()
        .map(|arg| {
            let arg_vec = to_vec(arg).unwrap();
            let arg_pointer = vm.write_pointer(arg_vec);
            RuntimeValue::I32(arg_pointer as i32)
        })
        .collect();
    let pointer = vm.call(&transaction.function, &arguments);
    let result = vm.read_pointer(pointer);
    let result_clone = result.clone();
    let (return_code_bytes, return_value_bytes) = result_clone.split_at(4);
    let mut return_code_bytes_fixed: [u8; 4] = Default::default();
    return_code_bytes_fixed.copy_from_slice(&return_code_bytes[0..4]);
    let return_code: u32 = unsafe{
        transmute(return_code_bytes_fixed)
    };
    let return_value: Value = serde_cbor::from_slice(return_value_bytes).unwrap();


    (return_code, return_value)
}
