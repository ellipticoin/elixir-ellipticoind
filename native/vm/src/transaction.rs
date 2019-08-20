extern crate base64;
pub use metered_wasmi::{isa, FunctionContext, RuntimeValue, NopExternals, Module, ModuleInstance, ImportsBuilder};
use serde::{Deserialize, Serialize};
use serde_cbor::Value;
use changeset::Changeset;
use env::Env;
use memory::Memory;
use block_index::BlockIndex;
use storage::Storage;
use vm::{VM, new_module_instance};
use result::{Result, self};
use ellipticoin_api::EllipticoinExternals;

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

impl Transaction {
    pub fn namespace(&self) -> Vec<u8> {
        let mut contract_name_bytes = self.contract_name.as_bytes().to_vec();
        let contract_name_len = contract_name_bytes.clone().len();
        contract_name_bytes.extend_from_slice(&vec![0; 32 - contract_name_len]);
        [self.contract_address.clone(), contract_name_bytes.to_vec()].concat()
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
        let mut memory = Memory::new(
            redis,
            &block_index,
            memory_changeset,
            self.namespace()
        );
        let mut storage = Storage::new(
            rocksdb,
            &block_index,
            storage_changeset,
            self.namespace(),
        );
        let code = storage.get(&"_code".as_bytes().to_vec());
        if code.len() == 0 {
            return (result::contract_not_found(self), None);
        }
        let module_instance = new_module_instance(code);
        let mut externals = EllipticoinExternals {
            memory: &mut memory,
            storage: &mut storage,
            env: &env,
            transaction: self,
            gas: Some(self.gas_limit as u32)
        };
        let mut vm = VM::new(
            &module_instance,
            &mut externals,
        );
        vm.call(&self.function, self.arguments.clone())
    }
}
