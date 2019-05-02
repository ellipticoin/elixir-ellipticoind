extern crate hex;
extern crate serialize;
use self::memory_units::Pages;
use db::DB;
use ellipticoin_api::*;
use env::Env;
use helpers::*;
use std::mem::transmute;
use transaction::Transaction;
use wasmi::RuntimeValue;
use wasmi::*;

pub struct VM<'a> {
    pub instance: &'a ModuleRef,
    pub db: &'a DB,
    pub transaction: &'a Transaction,
    pub env: &'a Env,
}

impl<'a> VM<'a> {
    pub fn new(
        db: &'a DB,
        env: &'a Env,
        transaction: &'a Transaction,
        main: &'a ModuleRef,
    ) -> VM<'a> {
        VM {
            instance: main,
            db: db,
            transaction: transaction,
            env: env,
        }
    }

    pub fn write_pointer(&mut self, vec: Vec<u8>) -> u32 {
        let vec_with_length = vec.to_vec_with_length();
        let vec_pointer = self.call(
            &"__malloc",
            &[RuntimeValue::I32(vec_with_length.len() as i32)],
        );
        self.memory()
            .set(vec_pointer, vec_with_length.as_slice())
            .unwrap();
        vec_pointer
    }

    pub fn read(&mut self, key: Vec<u8>) -> Vec<u8> {
        let contract_address = &self.transaction.contract_address;
        let mut contract_name = self.transaction.contract_name.as_bytes().to_vec().clone();

        let contract_name_len = contract_name.clone().len();
        contract_name.extend_from_slice(&vec![0; 32 - contract_name_len]);
        let key = [contract_address.clone(), contract_name.to_vec(), key].concat();
        let result = self.db.read(key.as_slice());

        result
    }

    pub fn write(&mut self, key: Vec<u8>, value: Vec<u8>) {
        let contract_address = &self.transaction.contract_address;
        let mut contract_name = self.transaction.contract_name.as_bytes().to_vec().clone();

        let contract_name_len = contract_name.len();
        contract_name.extend_from_slice(&vec![0; 32 - contract_name_len]);
        let key = [contract_address.to_vec(), contract_name.to_vec(), key].concat();
        self.db
            .write(self.env.block_number, key.as_slice(), value.as_slice());
    }

    pub fn read_pointer(&mut self, ptr: u32) -> Vec<u8> {
        let length_slice = self.memory().get(ptr, 4).unwrap();
        let mut length_u8 = [0 as u8; LENGTH_BYTE_COUNT];
        length_u8.clone_from_slice(&length_slice);
        let length: u32 = unsafe { (transmute::<[u8; 4], u32>(length_u8)) };
        let mem = self.memory().get(ptr + 4, length as usize).unwrap();
        mem
    }

    pub fn call(&mut self, func: &str, args: &[RuntimeValue]) -> u32 {
        match self.instance.invoke_export(func, args, self) {
            Ok(Some(RuntimeValue::I32(value))) => value as u32,
            Ok(Some(_)) => 0,
            Ok(None) => 0,
            Err(_e) => 0,
        }
    }

    pub fn memory(&self) -> MemoryRef {
        match self.instance.export_by_name("memory").unwrap() {
            ExternVal::Memory(x) => x,
            _ => MemoryInstance::alloc(Pages(256), None).unwrap(),
        }
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
