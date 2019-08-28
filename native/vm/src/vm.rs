extern crate hex;
extern crate serialize;
use self::memory_units::Pages;
use changeset::Changeset;
use ellipticoin_api::*;
use env::Env;
use gas_costs;
use helpers::i32_to_vec;
use metered_wasmi::RuntimeValue;
use metered_wasmi::*;
use result;
use serde_cbor::{to_vec, Value};
use std::mem;
use std::mem::transmute;

pub struct State<'a> {
    pub redis: &'a redis::Connection,
    pub rocksdb: &'a rocksdb::ReadOnlyDB,
    pub env: &'a Env,
    pub memory_changeset: &'a mut Changeset,
    pub storage_changeset: &'a mut Changeset,
}

pub struct VM<'a> {
    pub instance: &'a ModuleRef,
    pub externals: &'a mut EllipticoinExternals<'a>,
}

pub fn new_module_instance(code: Vec<u8>) -> ModuleRef {
    let module = Module::from_buffer(code).unwrap();

    let mut imports = ImportsBuilder::new();
    imports.push_resolver("env", &EllipticoinImportResolver);
    ModuleInstance::new(&module, &imports)
        .expect("Failed to instantiate module")
        .run_start(&mut NopExternals)
        .expect("Failed to run start function in module")
}

impl<'a> VM<'a> {
    pub fn new(instance: &'a ModuleRef, externals: &'a mut EllipticoinExternals<'a>) -> VM<'a> {
        VM {
            instance,
            externals,
        }
    }
    pub fn read_pointer(&mut self, ptr: i32) -> Vec<u8> {
        let length = self.read_i32(ptr);
        let offset = ptr + mem::size_of::<i32>() as i32;
        self.read_memory(offset, length)
    }

    fn read_i32(&mut self, ptr: i32) -> i32 {
        let mut fixed_slice: [u8; mem::size_of::<i32>()] = Default::default();
        let slice = self.read_memory(ptr, mem::size_of::<i32>() as i32);
        fixed_slice.copy_from_slice(&slice);
        unsafe { transmute(fixed_slice) }
    }

    pub fn write_pointer(
        &mut self,
        vec: Vec<u8>,
    ) -> Result<Option<RuntimeValue>, metered_wasmi::Trap> {
        let vec_with_length = [i32_to_vec(vec.len() as i32), vec].concat();
        match self.malloc(vec_with_length.len()) {
            Ok(vec_pointer) => {
                self.write_memory(vec_pointer, vec_with_length.as_slice());
                Ok(Some(RuntimeValue::I32(vec_pointer)))
            }
            Err(error) => Err(error),
        }
    }

    fn malloc(&mut self, size: usize) -> Result<i32, metered_wasmi::Trap> {
        match self
            .instance
            .invoke_export(&"__malloc", &[RuntimeValue::I32(size as i32)], self)
        {
            Ok(Some(RuntimeValue::I32(value))) => Ok(value),
            Err(_error) => Err(metered_wasmi::Trap::new(metered_wasmi::TrapKind::OutOfGas)),
            Ok(_) => panic!("malloc failed"),
        }
    }

    pub fn namespaced_key(&mut self, key: Vec<u8>) -> Vec<u8> {
        let contract_address = &self.externals.transaction.contract_address;
        let mut contract_name = self
            .externals
            .transaction
            .contract_name
            .as_bytes()
            .to_vec()
            .clone();

        let contract_name_len = contract_name.clone().len();
        contract_name.extend_from_slice(&vec![0; 32 - contract_name_len]);
        [contract_address.clone(), contract_name.to_vec(), key].concat()
    }

    pub fn call(&mut self, func: &str, arguments: Vec<Value>) -> (result::Result, Option<u32>) {
        let mut runtime_values: Vec<RuntimeValue> = vec![];
        for arg in arguments {
            let arg_vec = to_vec(&arg).expect("no args");
            match self.write_pointer(arg_vec) {
                Ok(Some(arg_pointer)) => runtime_values.push(arg_pointer),
                Ok(None) => return (result::vm_panic(), self.externals.gas),
                Err(_error) => return (result::vm_panic(), self.externals.gas),
            }
        }
        match self.instance.invoke_export(func, &runtime_values, self) {
            Ok(Some(RuntimeValue::I32(value))) => {
                self.externals.memory.commit();
                self.externals.storage.commit();
                (
                    result::from_bytes(self.read_pointer(value)),
                    self.externals.gas,
                )
            }
            Err(metered_wasmi::Error::Trap(_trap)) => {
                self.externals.memory.rollback();
                self.externals.storage.rollback();
                (result::vm_panic(), self.externals.gas)
            }
            _ => panic!("vm error"),
        }
    }

    pub fn read_memory(&self, pointer: i32, length: i32) -> Vec<u8> {
        match self
            .instance
            .export_by_name("memory")
            .expect("error reading memory")
        {
            ExternVal::Memory(x) => x.get(pointer as u32, length as usize).unwrap(),
            _ => vec![],
        }
    }

    pub fn write_memory(&self, pointer: i32, value: &[u8]) {
        match self.instance.export_by_name("memory").unwrap() {
            ExternVal::Memory(x) => x,
            _ => MemoryInstance::alloc(Pages(256), None).unwrap(),
        }
        .set(pointer as u32, value)
        .unwrap();
    }
}

impl<'a> Externals for VM<'a> {
    fn invoke_index(
        &mut self,
        index: usize,
        args: RuntimeArgs,
    ) -> Result<Option<RuntimeValue>, metered_wasmi::Trap> {
        EllipticoinExternals::invoke_index(self, index, args)
    }

    fn use_gas(&mut self, _instruction: &isa::Instruction) -> Result<(), TrapKind> {
        if let Some(gas) = self.externals.gas {
            if gas == 0 {
                Err(TrapKind::OutOfGas)
            } else {
                Ok(self.externals.gas = Some(gas - gas_costs::INSTRUCTION))
            }
        } else {
            Ok(())
        }
    }
}
