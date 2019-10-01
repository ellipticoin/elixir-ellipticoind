use wasm_rpc_macros::{export};
use wasm_rpc::error::Error;

#[export]
mod env {
    pub fn block_number() -> Result<u64, Error> {
        Ok(ellipticoin::block_number())
    }

    pub fn contract_address() -> Result<Vec<u8>, Error> {
        Ok(ellipticoin::contract_address())
    }
}
