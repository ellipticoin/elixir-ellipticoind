use ellipticoin_api::EllipticoinAPI;
use heck::SnakeCase;
use redis::{Commands, Connection};
use std::collections::{BTreeMap, HashMap};
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
            }).collect()
    };
}
use serde_cbor::{from_slice, to_vec, Value};
pub use wasmi::RuntimeValue;

#[derive(Clone, Debug)]
pub struct Transaction {
    pub code: Vec<u8>,
    pub env: HashMap<String, Vec<u8>>,
    pub method: String,
    pub params: Vec<Value>,
}

impl From<BTreeMap<String, Value>> for Transaction {
    fn from(transaction: BTreeMap<String, Value>) -> Self {
        let params = transaction
            .get("params")
            .unwrap()
            .as_array()
            .unwrap()
            .to_vec();
        let mut env: HashMap<String, Vec<u8>> = HashMap::new();
        let map = transaction.get("env").unwrap().as_object().unwrap();
        for (key, value) in map {
            env.insert(
                key.as_string().unwrap().to_string(),
                value.as_bytes().unwrap().to_vec(),
            );
        }

        Transaction {
            code: transaction
                .get("code")
                .unwrap()
                .as_bytes()
                .unwrap()
                .to_vec(),
            method: transaction
                .get("method")
                .unwrap()
                .as_string()
                .unwrap()
                .to_string(),
            env: env,
            params: params,
        }
    }
}

pub fn transaction_from_slice(transaction_bytes: &[u8]) -> Transaction {
    from_slice::<BTreeMap<String, Value>>(&transaction_bytes)
        .unwrap()
        .into()
}

pub fn run_transaction(transaction: &Transaction, db: &Connection) -> Vec<u8> {
    let module = EllipticoinAPI::new_module(&transaction.code);

    let mut vm = VM::new(db, &transaction.env, &module);
    let params: Vec<RuntimeValue> = transaction
        .params
        .iter()
        .map(|param| {
            let param_vec = to_vec(param).unwrap();
            let param_pointer = vm.write_pointer(param_vec);
            RuntimeValue::I32(param_pointer as i32)
        }).collect();
    let pointer = vm.call(&transaction.method, &params);
    let result = vm.read_pointer(pointer);

    result
}

// fn get_code(conn: &Connection, address: Vec<u8>, contract_name: &str) -> Vec<u8> {
//     if address == SYSTEM_ADDRESS.to_vec() &&
//         SYSTEM_CONTRACTS.contains_key(&contract_name) {
//         SYSTEM_CONTRACTS.get(&contract_name).unwrap().to_vec()
//     } else {
//         let mut user_contract_addess = Vec::new();
//         user_contract_addess.extend(SYSTEM_ADDRESS.to_vec());
//         user_contract_addess.extend(USER_CONTRACTS_NAME.bytes());
//         user_contract_addess.extend(contract_name.bytes());
//         conn.get::<_, Vec<u8>>(user_contract_addess).unwrap().to_vec()
//     }
// }
