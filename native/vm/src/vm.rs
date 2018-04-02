use helpers::*;
use wasmi::*;
use std::collections::HashMap;
use wasmi::RuntimeValue;
use memory_units::Pages;
use std::mem::transmute;
use elipticoin_api::*;
use ::DB;

pub struct VM<'a> {
    pub instance: &'a ModuleRef,
    pub db: &'a DB,
    pub env: &'a HashMap<String, &'a [u8]>,
}

impl<'a> VM<'a> {
    pub fn new(db: &'a DB, env: &'a HashMap<String, &'a [u8]>, main: &'a ModuleRef) -> VM<'a> {
        VM {
            instance: main,
            db: db,
            env: env,
        }
    }

    pub fn write_pointer(&mut self, vec: Vec<u8>) -> u32 {
        let vec_with_length = vec.to_vec_with_length();
        let vec_pointer = self.call(&"allocate", &[RuntimeValue::I32(vec_with_length.len() as i32)]);
        self.memory().set(vec_pointer, vec_with_length.as_slice()).unwrap();
        vec_pointer
    }

    pub fn read(&mut self, key: Vec<u8>) -> Vec<u8> {
        let contracts_address = self.env.get("address").unwrap().to_vec();
        let contract_id = self.env.get("contract_id").unwrap().to_vec();

        let key = [contracts_address, contract_id, key].concat();
        self.db.read(key.as_slice())

    }


    pub fn write(&mut self, key: Vec<u8>, value: Vec<u8>) {
        let contracts_address = self.env.get("address").unwrap().to_vec();
        let contract_id = self.env.get("contract_id").unwrap().to_vec();

        let key = [contracts_address, contract_id, key].concat();
        self.db.write(key.as_slice(), value.as_slice());
    }

    pub fn read_pointer(&mut self, ptr: u32) -> Vec<u8>{
        let length_slice = self.memory().get(ptr, 4).unwrap();
        let mut length_u8 = [0 as u8; LENGTH_BYTE_COUNT];
        length_u8.clone_from_slice(&length_slice);
        let length: u32 = unsafe {(transmute::<[u8; 4], u32>(length_u8)).to_be()};
        self.memory().get(ptr + 4, length as usize).unwrap()
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
        ElipticoinAPI::invoke_index(self, index, args)
    }
}
