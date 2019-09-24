use metered_wasmi::Error as InterpreterError;
use metered_wasmi::{FuncInstance, FuncRef, ModuleImportResolver, Signature, ValueType};
use std::str;
use vm::externals::*;

pub struct ImportResolver;
impl<'a> ModuleImportResolver for ImportResolver {
    fn resolve_func(
        &self,
        field_name: &str,
        _signature: &Signature,
    ) -> Result<FuncRef, InterpreterError> {
        let func_ref = match field_name {
            "__sender" => FuncInstance::alloc_host(
                Signature::new(&[][..], Some(ValueType::I32)),
                SENDER_FUNC_INDEX,
            ),
            "__block_hash" => FuncInstance::alloc_host(
                Signature::new(&[][..], Some(ValueType::I32)),
                BLOCK_HASH_FUNC_INDEX,
            ),
            "__block_number" => FuncInstance::alloc_host(
                Signature::new(&[][..], Some(ValueType::I32)),
                BLOCK_NUMBER_FUNC_INDEX,
            ),
            "__block_winner" => FuncInstance::alloc_host(
                Signature::new(&[][..], Some(ValueType::I32)),
                BLOCK_WINNER_FUNC_INDEX,
            ),
            "__caller" => FuncInstance::alloc_host(
                Signature::new(
                    &[][..],
                    Some(ValueType::I32),
                ),
                CALLER_FUNC_INDEX,
            ),
            "__get_memory" => FuncInstance::alloc_host(
                Signature::new(&[ValueType::I32][..], Some(ValueType::I32)),
                GET_MEMORY_FUNC_INDEX,
            ),
            "__set_memory" => FuncInstance::alloc_host(
                Signature::new(&[ValueType::I32, ValueType::I32][..], None),
                SET_MEMORY_FUNC_INDEX,
            ),
            "__get_storage" => FuncInstance::alloc_host(
                Signature::new(&[ValueType::I32][..], Some(ValueType::I32)),
                GET_STORAGE_FUNC_INDEX,
            ),
            "__set_storage" => FuncInstance::alloc_host(
                Signature::new(&[ValueType::I32, ValueType::I32][..], None),
                SET_STORAGE_FUNC_INDEX,
            ),
            "throw" => FuncInstance::alloc_host(
                Signature::new(&[ValueType::I32][..], None),
                THROW_FUNC_INDEX,
            ),
            "__call" => FuncInstance::alloc_host(
                Signature::new(
                    &[ValueType::I32, ValueType::I32, ValueType::I32][..],
                    Some(ValueType::I32),
                ),
                CALL_FUNC_INDEX,
            ),
            "__log_write" => FuncInstance::alloc_host(
                Signature::new(&[ValueType::I32, ValueType::I32][..], None),
                LOG_WRITE,
            ),
            _ => {
                return Err(InterpreterError::Function(format!(
                    "host module doesn't export function with name {}",
                    field_name.to_string()
                )));
            }
        };
        Ok(func_ref)
    }
}
