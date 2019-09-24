use helpers;
use serde_cbor::Value;
use std::intrinsics::transmute;
use transaction::Transaction;

pub type Result = (u32, Value);
pub fn vm_panic() -> Result {
    (1, "vm panic".to_string().into())
}

pub fn wasm_trap(trap: metered_wasmi::Trap) -> Result {
    (1, format!("WebAssembly Trap: {:?}", trap.kind()).into())
}

pub fn contract_not_found(_transaction: &Transaction) -> Result {
    (2, "Contract not found".to_string().into())
}

pub fn to_bytes(result: Result) -> Vec<u8> {
    let return_bytes = serde_cbor::to_vec(&result.1).unwrap();
    [helpers::u32_to_vec(result.0), return_bytes].concat()
}
pub fn from_bytes(bytes: Vec<u8>) -> Result {
    if bytes.len() == 0 {
        vm_panic()
    } else {
        let bytes_clone = bytes.clone();
        let (return_code_bytes, return_value_bytes) = bytes_clone.split_at(4);
        let mut return_code_bytes_fixed: [u8; 4] = Default::default();
        if bytes.len() == 0 {
            (1, "vm error".to_string().into())
        } else {
            return_code_bytes_fixed.copy_from_slice(&return_code_bytes[0..4]);
            let return_code: u32 = unsafe { transmute(return_code_bytes_fixed) };
            let return_value: Value = serde_cbor::from_slice(return_value_bytes).unwrap();

            (return_code, return_value)
        }
    }
}
