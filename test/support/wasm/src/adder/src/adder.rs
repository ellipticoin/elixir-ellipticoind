use wasm_rpc_macros::{export};
use wasm_rpc::error::Error;

#[export]
mod adder {
    pub fn add(a: u64, b: u64) -> Result<u64, Error> {
        Ok(a + b)
    }
}
