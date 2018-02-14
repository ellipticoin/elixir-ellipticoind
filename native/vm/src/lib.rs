#[macro_use] extern crate rustler;
#[macro_use] extern crate rustler_codegen;
#[macro_use] extern crate lazy_static;
extern crate wasmi;
extern crate rocksdb;
use rocksdb::DB;

mod helpers;
use helpers::*;
use std::mem;
use std::mem::transmute;
use std::env::args;

use wasmi::*;
use wasmi::RuntimeValue;
use wasmi::{Error as InterpreterError};
use memory_units::Pages;
use std::io::Write;


use rustler::{NifEnv, NifTerm, NifResult, NifEncoder};
use rustler::types::binary::{ NifBinary, OwnedNifBinary };

const LENGTH_BYTE_COUNT: usize = 4;
const SENDER: [u8; 20] = [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 ];

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
    memory: &'a mut MemoryRef,
    instance: &'a ModuleRef,
}

const SENDER_FUNC_INDEX: usize = 0;
const READ_FUNC_INDEX: usize = 1;
const WRITE_FUNC_INDEX: usize = 2;
const THROW_FUNC_INDEX: usize = 3;

impl<'a> Externals for Runtime<'a> {
    fn invoke_index(
        &mut self,
        index: usize,
        args: RuntimeArgs,
        ) -> Result<Option<RuntimeValue>, Trap> {
        match index {
            SENDER_FUNC_INDEX => {
                let vec_with_length = SENDER.to_vec().to_vec_with_length();
                let sender_pointer = call(self.instance,&mut self.memory,  &"alloc", vec_with_length.len() as u32);
                let _ = self.memory.set(sender_pointer, vec_with_length.as_slice());
                Ok(Some(sender_pointer.into()))
            }
            READ_FUNC_INDEX => {
                let db = DB::open_default("tmp/blockchain.db").unwrap();
                let key = read_pointer_with_length(self.memory, args.nth(0));

                let vec: Vec<u8> = match db.get(key.as_slice()) {
                    Ok(Some(value)) => value.to_vec(),
                    Ok(None) => vec![0],
                    Err(e) => vec![0],
                };
                let read_pointer = write_pointer_with_length(&self.instance, &mut self.memory, vec);
                Ok(Some(read_pointer.into()))
            }
            WRITE_FUNC_INDEX => {
                let key = read_pointer_with_length(self.memory, args.nth(0));
                let value = read_pointer_with_length(self.memory, args.nth(1));
                let db = DB::open_default("tmp/blockchain.db").unwrap();
                db.put(key.as_slice(), value.as_slice());
                println!("{:?} => {:?}", key, value);

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
            "sender" => {
                FuncInstance::alloc_host(Signature::new(&[][..], Some(ValueType::I32)), SENDER_FUNC_INDEX)
            },
            "read" => FuncInstance::alloc_host(Signature::new(&[ValueType::I32][..], Some(ValueType::I32)), READ_FUNC_INDEX),
            "write" => FuncInstance::alloc_host(Signature::new(&[ValueType::I32, ValueType::I32][..], None), WRITE_FUNC_INDEX),
            "throw" => FuncInstance::alloc_host(Signature::new(&[ValueType::I32][..], None), THROW_FUNC_INDEX),
            _ => return Err(
                InterpreterError::Function(
                    format!("host module doesn't export function with name {}", field_name)
                    )
                )
        };
        Ok(func_ref)
    }
}

fn memory(m: &ModuleRef) -> MemoryRef {
    match m.export_by_name("memory").unwrap() {
        ExternVal::Memory(x) => x,
        _ => MemoryInstance::alloc(Pages(256), None).unwrap(),
    }
}


// fn call_u32(m: &ModuleRef, func: &str, arg: u32) -> u32 {
//     let result = m.invoke_export(func, &[RuntimeValue::I32(arg as i32)], &mut NopExternals)
//         .unwrap().unwrap();
//     match result {
//         RuntimeValue::I32(x) => x as u32,
//         _ => 0 as u32,
//     }
// }

fn call(m: &ModuleRef, mut memory: &mut MemoryRef, func: &str, arg: u32) -> u32 {
    let mut runtime = Runtime {
        state: &mut VMState {},
        memory: &mut memory,
        instance: m,
    };
    match m.invoke_export(func, &[RuntimeValue::I32(arg as i32)], &mut runtime) {
        Ok(Some(RuntimeValue::I32(value))) => value as u32,
        Ok(Some(_)) => 0,
        Ok(None) => 0,
        Err(e) => 0,
    }
}

fn write_pointer_with_length(m: &ModuleRef, mut memory: &mut MemoryRef, vec: Vec<u8>) -> u32 {
    let vec_with_length = vec.to_vec_with_length();
    let vec_pointer = call(m, &mut memory, &"alloc", vec_with_length.len() as u32);
    memory.set(vec_pointer, vec_with_length.as_slice());
    vec_pointer
}

fn read_pointer_with_length(mut memory: &mut MemoryRef, ptr: u32) -> Vec<u8>{
    let length_slice = memory.get(ptr, 4).unwrap();
    let mut length_u8 = [0 as u8; LENGTH_BYTE_COUNT];
    length_u8.clone_from_slice(&length_slice);
    let length: u32 = unsafe {transmute(length_u8)};
    memory.get(ptr + 4, length.to_be() as usize).unwrap()
}

fn wasmi_run(code: Vec<u8>, func: &str, arg: &[u8]) -> Vec<u8> {
    let module = Module::from_buffer(code).unwrap();

    let mut imports = ImportsBuilder::new();
    imports.push_resolver("env", &RuntimeModuleImportResolver);
    let mut main = ModuleInstance::new(
        &module,
        &imports
    )
        .expect("Failed to instantiate module")
        .run_start(&mut NopExternals)
        .expect("Failed to run start function in module");

   let mut memory = memory(&main);

   let arg_pointer = write_pointer_with_length(&main, &mut memory, arg.to_vec());
   let pointer = call(&main, &mut memory, &func, arg_pointer);
   read_pointer_with_length(&mut memory, pointer)
   // let length_slice = memory.get(ptr, 4).unwrap();
   // let mut length_u8 = [0 as u8; LENGTH_BYTE_COUNT];
   // length_u8.clone_from_slice(&length_slice);
   // let length: u32 = unsafe {transmute(length_u8)};
   // memory.get(ptr + 4, length.to_be() as usize).unwrap()
   //  vec![]
    // length_slice

}

fn run<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let code: NifBinary = try!(args[0].decode());
    let func: &str = try!(args[1].decode());
    let arg: NifBinary = try!(args[2].decode());

    let output = wasmi_run(code.to_vec(), func, arg.as_slice());
    let mut binary = OwnedNifBinary::new(output.len()).unwrap();
    binary.as_mut_slice().write(&output).unwrap();
    // let output_bin: NifBinary = output.decode();
    // let output_erl = ErlNifBinary {
    // }
    // let output_bin  = NifBinary::from_raw(env, output);
    // Ok((atoms::ok(), binary).encode(env))
    Ok((atoms::ok(), binary.release(env)).encode(env))
}
