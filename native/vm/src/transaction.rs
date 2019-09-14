extern crate base64;
use block_index::BlockIndex;
use changeset::Changeset;
use ellipticoin_api::EllipticoinExternals;
use env::Env;
use memory::Memory;
pub use metered_wasmi::{
    isa, FunctionContext, ImportsBuilder, Module, ModuleInstance, NopExternals, RuntimeValue,
};
use result::{self, Result};
use serde::{Deserialize, Serialize};
use serde_cbor::Value;
use storage::Storage;
use vm::{new_module_instance, VM};

#[derive(Deserialize, Serialize, Debug)]
pub struct Transaction {
    #[serde(with = "serde_bytes")]
    pub contract_address: Vec<u8>,
    pub contract_name: String,
    #[serde(with = "serde_bytes")]
    pub sender: Vec<u8>,
    pub nonce: u64,
    pub gas_limit: u64,
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
    pub nonce: u64,
    pub gas_limit: u64,
    pub function: String,
    pub arguments: Vec<Value>,
    pub return_value: Value,
    pub return_code: u32,
}

pub fn namespace(contract_address: Vec<u8>, contract_name: &str) -> Vec<u8> {
    let mut contract_name_bytes = contract_name.as_bytes().to_vec();
    let contract_name_len = contract_name_bytes.clone().len();
    contract_name_bytes.extend_from_slice(&vec![0; 32 - contract_name_len]);
    [contract_address.clone(), contract_name_bytes.to_vec()].concat()
}

impl Transaction {
    pub fn namespace(&self) -> Vec<u8> {
        namespace(self.contract_address.clone(), &self.contract_name)
    }

    pub fn run(
        &self,
        redis: &redis::Connection,
        rocksdb: &rocksdb::ReadOnlyDB,
        env: &Env,
        memory_changeset: &mut Changeset,
        storage_changeset: &mut Changeset,
    ) -> (Result, Option<u32>) {
        let block_index = BlockIndex::new(redis);
        let mut memory = Memory::new(redis, &block_index, memory_changeset);
        let mut storage = Storage::new(rocksdb, &block_index, storage_changeset);
        let code = storage.get(
            &[
                namespace(
                    self.contract_address.clone(),
                    &self.contract_name.clone()
                ),
                "_code".as_bytes().to_vec()
            ].concat()
        );
        if code.len() == 0 {
            return (result::contract_not_found(self), Some(self.gas_limit as u32));
        }
        let module_instance = new_module_instance(code);
        let mut externals = EllipticoinExternals {
            memory: &mut memory,
            storage: &mut storage,
            env: &env,
            transaction: self,
            gas: Some(self.gas_limit as u32),
        };
        let mut vm = VM::new(&module_instance, &mut externals);
        vm.call(&self.function, self.arguments.clone())
    }
}
