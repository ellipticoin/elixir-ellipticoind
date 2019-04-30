use wasm_rpc_macros::{export};
use ellipticoin::{
    get_memory, set_memory, Value,
};
#[export]
mod memory {
    pub fn push(value: Value) {
        let mut stack: Vec<Value> = get_memory("value");
        stack.push(value);
        set_memory("value", stack);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_push() {
        let value = Value::String("test".to_string());
        push(value);
        let stack_bytes: Vec<u8> = get_memory("value".as_bytes().to_vec());
        let stack: Vec<Value> = serde_cbor::from_slice(&stack_bytes).unwrap();
        assert_eq!(stack, vec![Value::String("test".to_string())]);
    }
}
