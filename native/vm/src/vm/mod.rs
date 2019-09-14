extern crate hex;
extern crate serialize;
use env::Env;
use memory::Memory;
use metered_wasmi::{ImportsBuilder, Module, ModuleInstance, ModuleRef, NopExternals};
use storage::Storage;
use transaction::Transaction;
mod call;
mod externals;
mod gas;
mod import_resolver;
mod memory;

pub struct VM<'a> {
    pub instance: &'a ModuleRef,
    pub memory: &'a mut Memory,
    pub storage: &'a mut Storage,
    pub transaction: &'a Transaction,
    pub gas: Option<u32>,
    pub env: &'a Env,
}

pub fn new_module_instance(code: Vec<u8>) -> ModuleRef {
    let module = Module::from_buffer(code).unwrap();

    let mut imports = ImportsBuilder::new();
    imports.push_resolver("env", &import_resolver::ImportResolver);
    ModuleInstance::new(&module, &imports)
        .expect("Failed to instantiate module")
        .run_start(&mut NopExternals)
        .expect("Failed to run start function in module")
}
