use wasm_rpc_macros::{export};
use wasm_rpc::error::Error;

#[export]
mod env {
    pub fn block_number() -> Result<u64, Error> {
        Ok(ellipticoin::block_number())
    }
}
