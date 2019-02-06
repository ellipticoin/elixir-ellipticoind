use ellipticoin_api::EllipticoinAPI;
use heck::SnakeCase;
use redis::Connection;
use serde_cbor::Value;
use serde_derive::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::File;
use std::io::Read;

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
use serde_cbor::to_vec;
pub use wasmi::RuntimeValue;

#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct Transaction {
    #[serde(with = "serde_bytes")]
    pub contract_address: Vec<u8>,
    pub contract_name: String,
    #[serde(with = "serde_bytes")]
    pub code: Vec<u8>,
    #[serde(with = "serde_bytes")]
    pub sender: Vec<u8>,
    pub function: String,
    pub arguments: Vec<Value>,
}

pub fn run_transaction(transaction: &Transaction, db: &Connection) -> Vec<u8> {
    let module = EllipticoinAPI::new_module(&transaction.code);

    let mut vm = VM::new(db, transaction, &module);
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

    result
}
