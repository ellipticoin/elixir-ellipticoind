use serde_cbor::{from_slice, to_vec, Value};
use std::str;
use vm::*;
use wasmi::Error as InterpreterError;
use wasmi::*;

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

pub struct EllipticoinAPI;

impl EllipticoinAPI {
    pub fn new_module(code: &[u8]) -> ModuleRef {
        let module = Module::from_buffer(code).unwrap();

        let mut imports = ImportsBuilder::new();
        imports.push_resolver("env", &EllipticoinAPI);
        ModuleInstance::new(&module, &imports)
            .expect("Failed to instantiate module")
            .run_start(&mut NopExternals)
            .expect("Failed to run start function in module")
    }

    pub fn invoke_index(
        vm: &mut VM,
        index: usize,
        args: RuntimeArgs,
    ) -> Result<Option<RuntimeValue>, Trap> {
        match index {
            SENDER_FUNC_INDEX => Ok(Some(
                vm.write_pointer(vm.transaction.sender.to_vec()).into(),
            )),
            BLOCK_HASH_FUNC_INDEX => {
                let block_hash: serde_cbor::Value = vm.env.block_hash.clone().into();

                Ok(Some(vm.write_pointer(to_vec(&block_hash).unwrap()).into()))
            }
            BLOCK_NUMBER_FUNC_INDEX => {
                let block_number: serde_cbor::Value = vm.env.block_number.into();

                Ok(Some(
                    vm.write_pointer(to_vec(&block_number).unwrap()).into(),
                ))
            }
            BLOCK_WINNER_FUNC_INDEX => {
                Ok(Some(vm.write_pointer(vm.env.block_winner.clone()).into()))
            }
            GET_MEMORY_FUNC_INDEX => {
                let key = vm.read_pointer(args.nth(0));
                let value: Vec<u8> = vm.memory.get(vm.namespaced_key(key).as_slice());

                Ok(Some(vm.write_pointer(value).into()))
            }
            SET_MEMORY_FUNC_INDEX => {
                let key = vm.read_pointer(args.nth(0));
                let value = vm.read_pointer(args.nth(1));
                vm.memory.set(
                    vm.env.block_number,
                    vm.namespaced_key(key).as_slice(),
                    value.as_slice(),
                );

                Ok(None)
            }
            GET_STORAGE_FUNC_INDEX => {
                let key = vm.read_pointer(args.nth(0));
                let value: Vec<u8> = vm.storage.get(vm.namespaced_key(key).as_slice());

                Ok(Some(vm.write_pointer(value).into()))
            }
            SET_STORAGE_FUNC_INDEX => {
                let key = vm.read_pointer(args.nth(0));
                let value = vm.read_pointer(args.nth(1));
                vm.storage.set(
                    vm.env.block_number,
                    vm.namespaced_key(key).as_slice(),
                    value.as_slice(),
                );

                Ok(None)
            }
            THROW_FUNC_INDEX => Ok(None),
            CALL_FUNC_INDEX => {
                let code = vm.read_pointer(args.nth(0));
                let method = vm.read_pointer(args.nth(1));
                let args_value = from_slice::<Value>(&vm.read_pointer(args.nth(2))).unwrap();
                let args_iter: &Vec<Value> = args_value.as_array().unwrap();
                let _storage = vm.read_pointer(args.nth(3));

                let module = EllipticoinAPI::new_module(&code);
                let mut inner_vm = VM::new(vm.memory, vm.storage, vm.env, vm.transaction, &module);
                let mut args = Vec::new();
                for arg in args_iter {
                    if arg.is_number() {
                        args.push(RuntimeValue::I32(arg.as_u64().unwrap() as i32));
                    } else {
                        let arg_pointer = inner_vm.write_pointer(to_vec(&arg).unwrap());
                        args.push(RuntimeValue::I32(arg_pointer as i32));
                    }
                }

                let result_ptr = inner_vm.call(str::from_utf8(&method).unwrap(), &args);

                let result = inner_vm.read_pointer(result_ptr).clone();
                Ok(Some(vm.write_pointer(result.to_vec()).into()))
            }
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

impl<'a> ModuleImportResolver for EllipticoinAPI {
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
                    field_name
                )));
            }
        };
        Ok(func_ref)
    }
}
