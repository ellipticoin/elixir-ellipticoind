use metered_wasmi::Error as InterpreterError;
use metered_wasmi::*;
use serde_cbor::to_vec;
use std::str;
use vm::*;
use env::Env;
use transaction::Transaction;
use memory::Memory;
use storage::Storage;
use gas_costs;

const SENDER_FUNC_INDEX: usize = 0;
const BLOCK_HASH_FUNC_INDEX: usize = 1;
const BLOCK_NUMBER_FUNC_INDEX: usize = 2;
const BLOCK_WINNER_FUNC_INDEX: usize = 3;
const GET_MEMORY_FUNC_INDEX: usize = 4;
const SET_MEMORY_FUNC_INDEX: usize = 5;
const GET_STORAGE_FUNC_INDEX: usize = 6;
const SET_STORAGE_FUNC_INDEX: usize = 7;
const THROW_FUNC_INDEX: usize = 8;
const CALL_FUNC_INDEX: usize = 9;
const LOG_WRITE: usize = 10;


pub struct EllipticoinImportResolver;
pub struct EllipticoinExternals<'a> {
    pub memory: &'a mut Memory<'a>,
    pub storage: &'a mut Storage<'a>,
    pub transaction: &'a Transaction,
    pub gas: Option<u32>,
    pub env: &'a Env,
}

impl<'a> EllipticoinExternals<'a> {
    pub fn new(
        memory: &'a mut Memory<'a>,
        storage: &'a mut Storage<'a>,
        transaction: &'a Transaction,
        gas: Option<u32>,
        env: &'a Env,
    ) -> EllipticoinExternals<'a> {
        EllipticoinExternals {
            memory,
            storage,
            transaction,
            env,
            gas,
        }
    }

    pub fn invoke_index(
        vm: &mut VM,
        index: usize,
        args: RuntimeArgs,
    ) -> Result<Option<RuntimeValue>, metered_wasmi::Trap> {
        match index {
            SENDER_FUNC_INDEX => {
                vm.write_pointer(vm.externals.transaction.sender.to_vec())
            },
            BLOCK_HASH_FUNC_INDEX => {
                let block_hash: serde_cbor::Value = vm.externals.env.block_hash.clone().into();

                vm.write_pointer(to_vec(&block_hash).unwrap())
            }
            BLOCK_NUMBER_FUNC_INDEX => {
                let block_number: serde_cbor::Value = vm.externals.env.block_number.into();
                vm.write_pointer(to_vec(&block_number).unwrap())
            }
            BLOCK_WINNER_FUNC_INDEX => {
                vm.write_pointer(vm.externals.env.block_winner.clone())
            }
            GET_MEMORY_FUNC_INDEX => {
                let key = vm.read_pointer(args.nth(0));
                let value: Vec<u8> = vm.externals.memory.get(&key);
                use_gas_for_external(vm.externals, value.len() as u32 * gas_costs::GET_BYTE_MEMORY)?;
                vm.write_pointer(value)
            }
            SET_MEMORY_FUNC_INDEX => {
                let key = vm.read_pointer(args.nth(0));
                let value = vm.read_pointer(args.nth(1));
                use_gas_for_external(vm.externals, value.len() as u32 * gas_costs::SET_BYTE_MEMORY)?;
                vm.externals.memory.set(key, value);
                Ok(None)
            }
            GET_STORAGE_FUNC_INDEX => {
                let key = vm.read_pointer(args.nth(0));
                let value: Vec<u8> = vm.externals.storage.get(&key);
                use_gas_for_external(vm.externals, value.len() as u32 * gas_costs::GET_BYTE_STORAGE)?;
                vm.write_pointer(value)
            }
            SET_STORAGE_FUNC_INDEX => {
                let key = vm.read_pointer(args.nth(0));
                let value = vm.read_pointer(args.nth(1));
                use_gas_for_external(vm.externals, value.len() as u32 * gas_costs::SET_BYTE_STORAGE)?;
                vm.externals.storage.set(key, value);
                Ok(None)
            }
            THROW_FUNC_INDEX => Ok(None),
            CALL_FUNC_INDEX => Ok(None),
            LOG_WRITE => {
                let _log_level = vm.read_pointer(args.nth(0));
                let message = vm.read_pointer(args.nth(1));
                println!("{:?}", String::from_utf8(message));
                Ok(None)
            }
            _ => panic!("unknown function index"),
        }
    }

}

fn use_gas_for_external(externals: &mut EllipticoinExternals, amount: u32) -> Result<(), metered_wasmi::TrapKind>{
    if let Some(gas) = externals.gas {
        if gas < amount {
            Err(TrapKind::OutOfGas)
        } else {
            Ok(externals.gas = Some(gas - amount))
        }
    } else {
        Ok(())
    }
}

impl<'a> ModuleImportResolver for EllipticoinImportResolver {
    fn resolve_func(
        &self,
        field_name: &str,
        _signature: &Signature,
    ) -> Result<FuncRef, InterpreterError> {
        let func_ref = match field_name {
            "__sender" => FuncInstance::alloc_host(
                Signature::new(&[][..], Some(ValueType::I32)),
                SENDER_FUNC_INDEX,
            ),
            "__block_hash" => FuncInstance::alloc_host(
                Signature::new(&[][..], Some(ValueType::I32)),
                BLOCK_HASH_FUNC_INDEX,
            ),
            "__block_number" => FuncInstance::alloc_host(
                Signature::new(&[][..], Some(ValueType::I32)),
                BLOCK_NUMBER_FUNC_INDEX,
            ),
            "__block_winner" => FuncInstance::alloc_host(
                Signature::new(&[][..], Some(ValueType::I32)),
                BLOCK_WINNER_FUNC_INDEX,
            ),
            "__get_memory" => FuncInstance::alloc_host(
                Signature::new(&[ValueType::I32][..], Some(ValueType::I32)),
                GET_MEMORY_FUNC_INDEX,
            ),
            "__set_memory" => FuncInstance::alloc_host(
                Signature::new(&[ValueType::I32, ValueType::I32][..], None),
                SET_MEMORY_FUNC_INDEX,
            ),
            "__get_storage" => FuncInstance::alloc_host(
                Signature::new(&[ValueType::I32][..], Some(ValueType::I32)),
                GET_STORAGE_FUNC_INDEX,
            ),
            "__set_storage" => FuncInstance::alloc_host(
                Signature::new(&[ValueType::I32, ValueType::I32][..], None),
                SET_STORAGE_FUNC_INDEX,
            ),
            "throw" => FuncInstance::alloc_host(
                Signature::new(&[ValueType::I32][..], None),
                THROW_FUNC_INDEX,
            ),
            "_call" => FuncInstance::alloc_host(
                Signature::new(
                    &[
                        ValueType::I32,
                        ValueType::I32,
                        ValueType::I32,
                        ValueType::I32,
                    ][..],
                    Some(ValueType::I32),
                ),
                CALL_FUNC_INDEX,
            ),
            "__log_write" => FuncInstance::alloc_host(
                Signature::new(&[ValueType::I32, ValueType::I32][..], None),
                LOG_WRITE,
            ),
            _ => {
                return Err(InterpreterError::Function(format!(
                    "host module doesn't export function with name {}",
                    field_name.to_string()
                )));
            }
        };
        Ok(func_ref)
    }
}
