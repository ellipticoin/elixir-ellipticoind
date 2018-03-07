extern crate rocksdb;
use vm::*;
use wasmi::{Error as InterpreterError};
use wasmi::*;

const SENDER: [u8; 32] = [ 177, 20, 237, 76, 136, 182, 27, 70, 255, 84, 78, 145, 32, 22, 76, 181, 220, 73, 167, 17, 87, 194, 18, 247, 105, 149, 191, 29, 106, 236, 171, 14 ];
const SENDER_FUNC_INDEX: usize = 0;
const READ_FUNC_INDEX: usize = 1;
const WRITE_FUNC_INDEX: usize = 2;
const THROW_FUNC_INDEX: usize = 3;
const MEMCPY_FUNC_INDEX: usize = 4;
const RUST_BEGIN_UNWIND_FUNC_INDEX: usize = 5;

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
                Ok(Some(vm.write_pointer(SENDER.to_vec()).into()))
            }
            READ_FUNC_INDEX => {
                let key = vm.read_pointer(args.nth(0));

                let value: Vec<u8> = match vm.db.get(key.as_slice()) {
                    Ok(Some(value)) => value.to_vec(),
                    Ok(None) => vec![0,0,0,0,0,0,0,0],
                    Err(_e) => vec![0,0,0,0,0,0,0,0],
                };
                // println!("{:?} = {:?}", key, value);

                Ok(Some(vm.write_pointer(value).into()))
            }
            WRITE_FUNC_INDEX => {
                let key = vm.read_pointer(args.nth(0));
                let value = vm.read_pointer(args.nth(1));
                vm.db.put(key.as_slice(), value.as_slice())
                    .expect("failed to write");
                // println!("{:?} => {:?}", key, value);

                Ok(None)
            }
            THROW_FUNC_INDEX => {
                // let message = vm.read_pointer(args.nth(0));
                // println!("Thrown:");
                // println!("{:?}", message);
                Ok(None)
            }
            MEMCPY_FUNC_INDEX => {
                // let message = vm.read_pointer(args.nth(0));
                println!("Copying:");
                // println!("{:?}", message);
                Ok(Some((0).into()))
            }
            RUST_BEGIN_UNWIND_FUNC_INDEX => {
                // let message = vm.read_pointer(args.nth(0));
                println!("Copying:");
                // println!("{:?}", message);
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
            "rust_begin_unwind" => FuncInstance::alloc_host(Signature::new(&[ValueType::I32,ValueType::I32,ValueType::I32, ValueType::I32][..], None), RUST_BEGIN_UNWIND_FUNC_INDEX),
            _ => return Err(
                InterpreterError::Function(
                    format!("host module doesn't export function with name {}", field_name)
                    )
                )
        };
        Ok(func_ref)
    }
}
