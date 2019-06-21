use wasm_rpc_macros::{export};
use ellipticoin::{
    get_memory, set_memory, Value,
};
#[export]
mod memory {
    pub fn constructor(value: Vec<u8>) {
        set_memory("value", value);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_push() {
        constructor(vec![1, 2, 3]);
        assert_eq!(get_memory::<_, Vec<u8>>("value"), vec![1, 2, 3]);
    }
}
