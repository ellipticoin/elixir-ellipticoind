use wasm_rpc_macros::{export};
use ellipticoin::Value;
#[export]
mod state {
    pub fn set_memory(value: Value) {
        ellipticoin::set_memory("value", value);
    }

    pub fn set_storage(value: Value) {
        ellipticoin::set_storage("value", value);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_set_memory() {
        set_memory(Value::String("test".into()));
        let stack_bytes: Vec<u8> = ellipticoin::get_memory("value".as_bytes().to_vec());
        let value: Value = serde_cbor::from_slice(&stack_bytes).unwrap();
        assert_eq!(value, Value::String("test".to_string()));
    }

    #[test]
    fn test_set_storage() {
        set_storage(Value::String("test".into()));
        let stack_bytes: Vec<u8> = ellipticoin::get_storage("value".as_bytes().to_vec());
        let value: Value = serde_cbor::from_slice(&stack_bytes).unwrap();
        assert_eq!(value, Value::String("test".to_string()));
    }
}
