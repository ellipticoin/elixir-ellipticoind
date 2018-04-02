use vm::*;
use wasmi::{Error as InterpreterError};
use serde_cbor::{from_slice, to_vec, Value};
use wasmi::*;
use std::str;


const SENDER_FUNC_INDEX: usize = 0;
const READ_FUNC_INDEX: usize = 1;
const WRITE_FUNC_INDEX: usize = 2;
const THROW_FUNC_INDEX: usize = 3;
const MEMCPY_FUNC_INDEX: usize = 4;
const CALL_FUNC_INDEX: usize = 5;
const RUST_BEGIN_UNWIND_FUNC_INDEX: usize = 6;

pub struct ElipticoinAPI;

impl ElipticoinAPI {
    pub fn new_module(code: &[u8]) -> ModuleRef {
        let module = Module::from_buffer(code).unwrap();

        let mut imports = ImportsBuilder::new();
        imports.push_resolver("env", &ElipticoinAPI);
        ModuleInstance::new(
            &module,
            &imports
        )
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
            SENDER_FUNC_INDEX => {
                if let Some(sender) = vm.env.get("sender") {
                    Ok(Some(vm.write_pointer(sender.to_vec()).into()))
                } else {
                    Ok(None)
                }
            }
            READ_FUNC_INDEX => {
                let key = vm.read_pointer(args.nth(0));
                let value: Vec<u8> = vm.read(key);
                Ok(Some(vm.write_pointer(value).into()))
            }
            WRITE_FUNC_INDEX => {
                let key = vm.read_pointer(args.nth(0));
                let value = vm.read_pointer(args.nth(1));
                vm.write(key, value);

                Ok(None)
            }
            THROW_FUNC_INDEX => {
                Ok(None)
            }
            MEMCPY_FUNC_INDEX => {
                Ok(Some((0).into()))
            }
            CALL_FUNC_INDEX => {
                let code = vm.read_pointer(args.nth(0));
                let method = vm.read_pointer(args.nth(1));
                let args_value = from_slice::<Value>(&vm.read_pointer(args.nth(2))).unwrap();
                let args_iter: &Vec<Value> = args_value
                    .as_array()
                    .unwrap();
                let _storage = vm.read_pointer(args.nth(3));

                let module = ElipticoinAPI::new_module(&code);
                let mut inner_vm = VM::new(vm.db, &vm.env, &module);
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
            RUST_BEGIN_UNWIND_FUNC_INDEX => {
                Ok(None)
            }
            _ => panic!("unknown function index")
        }
    }
}

impl<'a> ModuleImportResolver for ElipticoinAPI {
    fn resolve_func(
        &self,
        field_name: &str,
        _signature: &Signature,
        ) -> Result<FuncRef, InterpreterError> {
        let func_ref = match field_name {
            "sender" => {
                FuncInstance::alloc_host(Signature::new(&[][..], Some(ValueType::I32)), SENDER_FUNC_INDEX)
            },
            "read" => FuncInstance::alloc_host(Signature::new(&[ValueType::I32][..], Some(ValueType::I32)), READ_FUNC_INDEX),
            "write" => FuncInstance::alloc_host(Signature::new(&[ValueType::I32, ValueType::I32][..], None), WRITE_FUNC_INDEX),
            "throw" => FuncInstance::alloc_host(Signature::new(&[ValueType::I32][..], None), THROW_FUNC_INDEX),
            "memcpy" => FuncInstance::alloc_host(Signature::new(&[ValueType::I32,ValueType::I32,ValueType::I32][..], Some(ValueType::I32)), MEMCPY_FUNC_INDEX),
            "_call" => FuncInstance::alloc_host(Signature::new(&[ValueType::I32, ValueType::I32, ValueType::I32, ValueType::I32][..], Some(ValueType::I32)), CALL_FUNC_INDEX),
            "rust_begin_unwind" => FuncInstance::alloc_host(Signature::new(&[ValueType::I32, ValueType::I32, ValueType::I32, ValueType::I32, ValueType::I32, ValueType::I32, ValueType::I32, ValueType::I32, ValueType::I32, ValueType::I32][..], None), RUST_BEGIN_UNWIND_FUNC_INDEX),
            _ => return Err(
                InterpreterError::Function(
                    format!("host module doesn't export function with name {}", field_name)
                    )
                )
        };
        Ok(func_ref)
    }
}
