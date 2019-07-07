extern crate hex;
extern crate serialize;
use self::memory_units::Pages;
use ellipticoin_api::*;
use env::Env;
use helpers::*;
use memory::Memory;
use std::mem::transmute;
use storage::Storage;
use transaction::{Transaction, Changeset};
use wasmi::RuntimeValue;
use wasmi::*;

pub struct VM<'a> {
    pub instance: &'a ModuleRef,
    pub memory: &'a Memory<'a>,
    pub memory_changeset: &'a mut Changeset,
    pub storage: &'a Storage<'a>,
    pub storage_changeset: &'a mut Changeset,
    pub transaction: &'a Transaction,
    pub env: &'a Env,
}

impl<'a> VM<'a> {
    pub fn new(
        memory_changeset: &'a mut Changeset,
        memory: &'a Memory,
        storage_changeset: &'a mut Changeset,
        storage: &'a Storage,
        env: &'a Env,
        transaction: &'a Transaction,
        instance: &'a ModuleRef,
    ) -> VM<'a> {
        VM {
            instance: instance,
            memory: memory,
            memory_changeset: memory_changeset,
            storage: storage,
            storage_changeset: storage_changeset,
            transaction: transaction,
            env: env,
        }
    }

    pub fn read_pointer(&mut self, ptr: u32) -> Vec<u8> {
        let length = self.read_pointer_length(ptr);
        self.read_vm_memory(ptr + 4, length as usize)
    }

    fn read_pointer_length(&mut self, ptr: u32) -> u32 {
        let mut length_u8 = [0 as u8; LENGTH_BYTE_COUNT];
        let length_slice = self.read_vm_memory(ptr, LENGTH_BYTE_COUNT);
        length_u8.clone_from_slice(&length_slice);
        unsafe { (transmute::<[u8; LENGTH_BYTE_COUNT], u32>(length_u8)) }
    }

    pub fn write_pointer(&mut self, vec: Vec<u8>) -> u32 {
        let vec_with_length = vec.to_vec_with_length();
        let vec_pointer = self.malloc(vec_with_length.len() as i32);
        self.write_vm_memory(vec_pointer, vec_with_length.as_slice());
        vec_pointer
    }

    fn malloc(&mut self, size: i32) -> u32 {
        self.call(&"__malloc", &[RuntimeValue::I32(size)])
    }

    pub fn namespaced_key(&mut self, key: Vec<u8>) -> Vec<u8> {
        let contract_address = &self.transaction.contract_address;
        let mut contract_name = self.transaction.contract_name.as_bytes().to_vec().clone();

        let contract_name_len = contract_name.clone().len();
        contract_name.extend_from_slice(&vec![0; 32 - contract_name_len]);
        [contract_address.clone(), contract_name.to_vec(), key].concat()
    }

    pub fn call(&mut self, func: &str, args: &[RuntimeValue]) -> u32 {
        match self.instance.invoke_export(func, args, self) {
            Ok(Some(RuntimeValue::I32(value))) => value as u32,
            Ok(Some(_)) => 0,
            Ok(None) => 0,
            Err(_e) => 0,
        }
    }

    pub fn read_vm_memory(&self, pointer: u32, length: usize) -> Vec<u8> {
        match self.instance.export_by_name("memory").unwrap() {
            ExternVal::Memory(x) => x.get(pointer, length).unwrap(),
            _ => vec![],
        }
    }

    pub fn write_vm_memory(&self, pointer: u32, value: &[u8]) {
        match self.instance.export_by_name("memory").unwrap() {
            ExternVal::Memory(x) => x,
            _ => MemoryInstance::alloc(Pages(256), None).unwrap(),
        }
        .set(pointer, value)
        .unwrap();
    }
}

impl<'a> Externals for VM<'a> {
    fn invoke_index(
        &mut self,
        index: usize,
        args: RuntimeArgs,
    ) -> Result<Option<RuntimeValue>, Trap> {
        EllipticoinAPI::invoke_index(self, index, args)
    }
}
