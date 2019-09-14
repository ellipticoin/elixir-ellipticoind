use helpers::i32_to_vec;
use metered_wasmi::{memory_units::Pages, ExternVal, MemoryInstance, RuntimeValue};
use std::mem::{self, transmute};
use vm::VM;

impl<'a> VM<'a> {
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
