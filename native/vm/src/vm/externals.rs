use gas_costs;
use metered_wasmi::{isa, RuntimeArgs, RuntimeValue, TrapKind};
use result;
use serde_cbor::{from_slice, to_vec};
use std::str;
use transaction::namespace;
use vm::new_module_instance;
use vm::VM;
use transaction::Transaction;

pub const SENDER_FUNC_INDEX: usize = 0;
pub const BLOCK_HASH_FUNC_INDEX: usize = 1;
pub const BLOCK_NUMBER_FUNC_INDEX: usize = 2;
pub const BLOCK_WINNER_FUNC_INDEX: usize = 3;
pub const GET_MEMORY_FUNC_INDEX: usize = 4;
pub const SET_MEMORY_FUNC_INDEX: usize = 5;
pub const GET_STORAGE_FUNC_INDEX: usize = 6;
pub const SET_STORAGE_FUNC_INDEX: usize = 7;
pub const THROW_FUNC_INDEX: usize = 8;
pub const CALL_FUNC_INDEX: usize = 9;
pub const LOG_WRITE: usize = 10;

impl<'a> VM<'a> {
    pub fn sender(&self) -> Vec<u8> {
        self.transaction.sender.to_vec()
    }

    pub fn block_hash(&self) -> Vec<u8> {
        self.env.block_hash.clone()
    }

    pub fn block_number(&self) -> Vec<u8> {
        let block_number: serde_cbor::Value = self.env.block_number.into();
        to_vec(&block_number).unwrap()
    }

    pub fn block_winner(&self) -> Vec<u8> {
        self.env.block_winner.clone()
    }

    pub fn get_memory(&mut self, key_pointer: i32) -> Result<Vec<u8>, metered_wasmi::TrapKind> {
        let key = self.read_pointer(key_pointer);
        let value = self.memory.get(&self.namespaced_key(key.clone()));

        self.use_gas(value.len() as u32 * gas_costs::GET_BYTE_MEMORY)?;
        Ok(value)
    }

    pub fn set_memory(
        &mut self,
        key_pointer: i32,
        value_pointer: i32,
    ) -> Result<Option<RuntimeValue>, metered_wasmi::Trap> {
        let key = self.read_pointer(key_pointer);
        let value = self.read_pointer(value_pointer);
        self.use_gas(value.len() as u32 * gas_costs::SET_BYTE_MEMORY)?;
        self.memory.set(self.namespaced_key(key), value);
        Ok(None)
    }

    pub fn get_storage(&mut self, key_pointer: i32) -> Result<Vec<u8>, metered_wasmi::TrapKind> {
        let key = self.read_pointer(key_pointer);
        let value = self.storage.get(&self.namespaced_key(key));

        self.use_gas(value.len() as u32 * gas_costs::GET_BYTE_STORAGE)?;
        Ok(value)
    }

    pub fn set_storage(
        &mut self,
        key_pointer: i32,
        value_pointer: i32,
    ) -> Result<Option<RuntimeValue>, metered_wasmi::Trap> {
        let key = self.read_pointer(key_pointer);
        let value = self.read_pointer(value_pointer);
        self.use_gas(value.len() as u32 * gas_costs::SET_BYTE_STORAGE)?;
        self.storage.set(self.namespaced_key(key), value);
        Ok(None)
    }

    pub fn external_call(
        &mut self,
        contract_depolyer_pointer: i32,
        contract_name_pointer: i32,
        function_name_pointer: i32,
        arguments_pointer: i32,
    ) -> Result<Vec<u8>, metered_wasmi::Trap> {
        let contract_depolyer = self.read_pointer(contract_depolyer_pointer);
        let contract_name_bytes = &self.read_pointer(contract_name_pointer);
        let contract_name = str::from_utf8(contract_name_bytes).unwrap();
        let function_name_bytes = self.read_pointer(function_name_pointer);
        let function_name = str::from_utf8(&function_name_bytes).unwrap();
        let arguments = from_slice(&self.read_pointer(arguments_pointer)).unwrap();
        let code = self
            .storage
            .get(&namespace(contract_depolyer, &contract_name));
        if code.len() == 0 {
            return Ok(to_vec(&(
                result::contract_not_found(self.transaction),
                Some(self.transaction.gas_limit as u32),
            ))
            .unwrap());
        }
        let module_instance = new_module_instance(code);
        let mut transaction: Transaction = (*self.transaction).clone();
        transaction.contract_name = contract_name.to_string();
        transaction.function = function_name.to_string();
        let mut vm = VM {
            instance: &module_instance,
            memory: &mut self.memory,
            storage: &mut self.storage,
            env: &self.env,
            transaction: &transaction,
            gas: self.gas,
        };
        let (result, gas_left) = vm.call(function_name, arguments);
        let gas_used = self.gas.unwrap() - gas_left.expect("no gas left");
        self.use_gas(gas_used)?;
        Ok(result::to_bytes(result))
    }

    pub fn namespaced_key(&self, key: Vec<u8>) -> Vec<u8> {
        [
            namespace(
                self.transaction.contract_address.clone(),
                &self.transaction.contract_name.clone(),
            ),
            key.clone(),
        ]
        .concat()
    }

    pub fn log(
        &mut self,
        log_level_pointer: i32,
        log_message_pointer: i32,
    ) -> Result<Option<RuntimeValue>, metered_wasmi::Trap> {
        let _log_level = self.read_pointer(log_level_pointer);
        let message = self.read_pointer(log_message_pointer);
        println!("debug: {:?}", str::from_utf8(&message).unwrap());
        Ok(None)
    }
}

impl metered_wasmi::Externals for VM<'_> {
    fn use_gas(&mut self, _instruction: &isa::Instruction) -> Result<(), TrapKind> {
        self.use_gas(gas_costs::INSTRUCTION)
    }

    fn invoke_index(
        &mut self,
        index: usize,
        args: RuntimeArgs,
    ) -> Result<Option<RuntimeValue>, metered_wasmi::Trap> {
        match index {
            SENDER_FUNC_INDEX => self.write_pointer(self.sender()),
            BLOCK_HASH_FUNC_INDEX => self.write_pointer(self.block_hash()),
            BLOCK_NUMBER_FUNC_INDEX => self.write_pointer(self.block_number()),
            BLOCK_WINNER_FUNC_INDEX => self.write_pointer(self.block_winner()),
            GET_MEMORY_FUNC_INDEX => {
                let value_pointer = self.get_memory(args.nth(0))?;
                self.write_pointer(value_pointer)
            }
            SET_MEMORY_FUNC_INDEX => self.set_memory(args.nth(0), args.nth(1)),
            GET_STORAGE_FUNC_INDEX => {
                let value_pointer = self.get_storage(args.nth(0))?;
                self.write_pointer(value_pointer)
            }
            SET_STORAGE_FUNC_INDEX => self.set_storage(args.nth(0), args.nth(1)),
            THROW_FUNC_INDEX => Ok(None),
            CALL_FUNC_INDEX => {
                let result_bytes =
                    self.external_call(args.nth(0), args.nth(1), args.nth(2), args.nth(3))?;
                self.write_pointer(result_bytes)
            }
            LOG_WRITE => self.log(args.nth(0), args.nth(1)), //{
            _ => panic!("Called an unknown function index"),
        }
    }
}
