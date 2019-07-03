extern crate base64;
use block_index::BlockIndex;
use ellipticoin_api::EllipticoinAPI;
use env::Env;
use heck::SnakeCase;
use memory::Memory;
use storage::Storage;
use serde::{Deserialize, Serialize};
use serde_cbor::Value;
use std::collections::HashMap;
use std::fs::File;
use std::io::Read;
use std::mem::transmute;

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

#[derive(Deserialize, Serialize, Debug)]
pub struct Transaction {
    #[serde(with = "serde_bytes")]
    pub contract_address: Vec<u8>,
    pub contract_name: String,
    #[serde(with = "serde_bytes")]
    pub sender: Vec<u8>,
    pub nonce: u64,
    pub function: String,
    pub arguments: Vec<Value>,
}

pub type Changeset = HashMap<Vec<u8>, Vec<u8>>;
#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct CompletedTransaction {
    #[serde(with = "serde_bytes")]
    pub contract_address: Vec<u8>,
    pub contract_name: String,
    #[serde(with = "serde_bytes")]
    pub sender: Vec<u8>,
    pub nonce: u64,
    pub function: String,
    pub arguments: Vec<Value>,
    pub return_value: Value,
    pub return_code: u32,
    pub execution_order: u64,
}
impl Transaction {
    pub fn namespace(&self) -> Vec<u8>{
        namespace(&self.contract_address, &self.contract_name)
    }
}
fn namespace(contract_address: &[u8], contract_name_string: &str)
-> Vec<u8> {
    let mut contract_name = contract_name_string.as_bytes().to_vec();
    let contract_name_len = contract_name.clone().len();
    contract_name.extend_from_slice(&vec![0; 32 - contract_name_len]);
    [contract_address.clone(), &contract_name.to_vec()].concat()
}

pub fn run_in_vm(mut memory_changeset: &mut Changeset, transaction: &Transaction, redis: &redis::Connection, rocksdb: &rocksdb::DB, env: &Env) -> (u32, Value) {
    let block_index = BlockIndex::new(redis);
    let memory = Memory::new(redis, &block_index, transaction.namespace());
    let storage = Storage::new(rocksdb, &block_index, transaction.namespace());
    let code = storage.get("_code".as_bytes());
    if code.len() == 0 {
        return (1, format!("{} not found", transaction.contract_name.to_string()).into())
    }
    let module = EllipticoinAPI::new_module(&code);

    let mut vm = VM::new(&mut memory_changeset, &memory, &storage, &env, transaction, &module);
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
    let return_code: u32 = unsafe { transmute(return_code_bytes_fixed) };
    let return_value: Value = serde_cbor::from_slice(return_value_bytes).unwrap();

    (return_code, return_value)
}

pub fn run_system_contract(memory_changeset: &mut Changeset, transaction: &Transaction, redis: &redis::Connection, rocksdb: &rocksdb::DB, env: &Env) -> (u32, Value) {
    match transaction.function.as_str() {
        "create_contract" => {
            let contract_name = transaction.arguments[0].as_string().unwrap();
            let code = transaction.arguments[1].as_bytes().unwrap();
            let namespace = namespace(&transaction.sender, contract_name);
            let block_index = BlockIndex::new(redis);
            let storage = Storage::new(rocksdb, &block_index, namespace.clone());
            storage.set(env.block_number, "_code".as_bytes(), code);
            run_in_vm(
                memory_changeset,
                &Transaction {
                    function: "constructor".to_string(),
                    arguments: transaction.arguments[2].as_array().unwrap().to_vec(),
                    sender: transaction.sender.clone(),
                    nonce: transaction.nonce,
                    contract_name: contract_name.to_string(),
                    contract_address: transaction.sender.clone(),
                }, redis, rocksdb, env)
        }
        _ => (0, Value::Null)
    }
}
pub fn run_transaction(transaction: &Transaction, redis: &redis::Connection, rocksdb: &rocksdb::DB, env: &Env, mut memory_changeset: &mut Changeset) -> (u32, Value) {
    if transaction.contract_address == [0; 32] &&
        transaction.contract_name == "system" {
        run_system_contract(&mut memory_changeset, transaction, redis, rocksdb, env)
    } else {
        run_in_vm(&mut memory_changeset, transaction, redis, rocksdb, env)
    }
}
