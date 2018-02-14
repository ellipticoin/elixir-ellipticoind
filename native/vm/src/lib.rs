#[macro_use] extern crate rustler;
#[macro_use] extern crate rustler_codegen;
#[macro_use] extern crate lazy_static;
extern crate wasmi;

use std::mem;
use std::mem::transmute;
use std::env::args;

use wasmi::*;
use wasmi::RuntimeValue;
use wasmi::{Error as InterpreterError};
use memory_units::Pages;


use rustler::{NifEnv, NifTerm, NifResult, NifEncoder};
use ::rustler::types::binary::NifBinary;

mod atoms {
    rustler_atoms! {
        atom ok;
    }
}

rustler_export_nifs! {
    "Elixir.VM",
    [("run", 3, run)],
    None
}
pub struct VMState {
}

struct Env {
    table_base: GlobalRef,
    memory_base: GlobalRef,
    memory: MemoryRef,
    table: TableRef,
}

impl Env {
    fn new() -> Env {
        Env {
            table_base: GlobalInstance::alloc(RuntimeValue::I32(0), false),
            memory_base: GlobalInstance::alloc(RuntimeValue::I32(0), false),
            memory: MemoryInstance::alloc(Pages(256), None).unwrap(),
            table: TableInstance::alloc(64, None).unwrap(),
        }
    }
}

impl ModuleImportResolver for Env {
    fn resolve_func(&self, _field_name: &str, _func_type: &Signature) -> Result<FuncRef, Error> {
        Err(Error::Instantiation(
                "env module doesn't provide any functions".into(),
                ))
    }
    // fn resolve_func(
    //     &self,
    //     field_name: &str,
    //     _signature: &Signature,
    //     ) -> Result<FuncRef, InterpreterError> {
    //     // println!("resolving!");
    //     let func_ref = match field_name {
    //         "print" => {
    //             FuncInstance::alloc_host(Signature::new(&[ValueType::I32][..], Some(ValueType::I32)), PRINT_FUNC_INDEX)
    //         }
    //         _ => return Err(
    //             InterpreterError::Function(
    //                 format!("host module doesn't export function with name {}", field_name)
    //                 )
    //             )
    //         };
    //     Ok(func_ref)
    // }

    fn resolve_global(
        &self,
        field_name: &str,
        _global_type: &GlobalDescriptor,
        ) -> Result<GlobalRef, Error> {
        match field_name {
            "tableBase" => Ok(self.table_base.clone()),
            "memoryBase" => Ok(self.memory_base.clone()),
            _ => Err(Error::Instantiation(format!(
                        "env module doesn't provide global '{}'",
                        field_name
                        ))),
        }
    }

    fn resolve_memory(
        &self,
        field_name: &str,
        _memory_type: &MemoryDescriptor,
        ) -> Result<MemoryRef, Error> {
        match field_name {
            "memory" => Ok(self.memory.clone()),
            _ => Err(Error::Instantiation(format!(
                        "env module doesn't provide memory '{}'",
                        field_name
                        ))),
        }
    }

    fn resolve_table(&self, field_name: &str, _table_type: &TableDescriptor) -> Result<TableRef, Error> {
        match field_name {
            "table" => Ok(self.table.clone()),
            _ => Err(Error::Instantiation(
                    format!("env module doesn't provide table '{}'", field_name),
                    )),
        }
    }
}


struct Runtime<'a> {
    state: &'a mut VMState,
}

const PRINT_FUNC_INDEX: usize = 0;
// const SENDER_FUNC_INDEX: usize = 0;
// const READ_FUNC_INDEX: usize = 1;
// const WRITE_FUNC_INDEX: usize = 2;
// const THROW_FUNC_INDEX: usize = 3;
//
impl<'a> Externals for Runtime<'a> {
    fn invoke_index(
        &mut self,
        index: usize,
        args: RuntimeArgs,
        ) -> Result<Option<RuntimeValue>, Trap> {
        match index {
            PRINT_FUNC_INDEX => {
                let idx: i32 = args.nth(0);
                println!("{}", idx);
                Ok(Some(0.into()))
            }
            SENDER_FUNC_INDEX => {
                println!("Sender");
                Ok(Some(0.into()))
            }
            READ_FUNC_INDEX => {
                println!("Read");
                Ok(Some(0.into()))
            }
            WRITE_FUNC_INDEX => {
                println!("Write");
                Ok(None)
            }
            THROW_FUNC_INDEX => {
                Ok(None)
            }
            _ => panic!("unknown function index")
        }
    }
}

struct RuntimeModuleImportResolver;

impl<'a> ModuleImportResolver for RuntimeModuleImportResolver {
    fn resolve_func(
        &self,
        field_name: &str,
        _signature: &Signature,
        ) -> Result<FuncRef, InterpreterError> {
        let func_ref = match field_name {
            "print" => {
                FuncInstance::alloc_host(Signature::new(&[ValueType::I32][..], Some(ValueType::I32)), PRINT_FUNC_INDEX)
            },
            // "sender" => {
            //     FuncInstance::alloc_host(Signature::new(&[][..], Some(ValueType::I32)), SENDER_FUNC_INDEX)
            // },
            // "read" => FuncInstance::alloc_host(Signature::new(&[ValueType::I32][..], Some(ValueType::I32)), READ_FUNC_INDEX),
            // "write" => FuncInstance::alloc_host(Signature::new(&[ValueType::I32, ValueType::I32][..], None), WRITE_FUNC_INDEX),
            // "throw" => FuncInstance::alloc_host(Signature::new(&[ValueType::I32][..], None), THROW_FUNC_INDEX),
            _ => return Err(
                InterpreterError::Function(
                    format!("host module doesn't export function with name {}", field_name)
                    )
                )
        };
        Ok(func_ref)
    }
}

fn wasmi_run(code: Vec<u8>, func: &str, arg: &[u8]) -> i32 {
    let module = Module::from_buffer(code).unwrap();

    let mut imports = ImportsBuilder::new();
    imports.push_resolver("env", &RuntimeModuleImportResolver);
    let main = ModuleInstance::new(
        &module,
        &imports
    )
        .expect("Failed to instantiate module")
        .run_start(&mut NopExternals)
        .expect("Failed to run start function in module");

    let memory = match main.export_by_name("memory").unwrap() {
        ExternVal::Memory(x) => x,
        _ => MemoryInstance::alloc(Pages(256), None).unwrap(),
    };
    let _ = memory.set(0, arg);

     let args = &[RuntimeValue::I32(arg.len() as i32), RuntimeValue::I32(0 as i32)];
    let result = main.invoke_export(func, args, &mut NopExternals)
        .unwrap().unwrap();


    match result {
        RuntimeValue::I32(x) => x,
        _ => 0,
    }
}

fn run<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let code: NifBinary = try!(args[0].decode());
    let func: &str = try!(args[1].decode());
    let arg: NifBinary = try!(args[2].decode());

    let output = wasmi_run(code.to_vec(), func, arg.as_slice());
    Ok((atoms::ok(), output).encode(env))
}
