use wasm_rpc_macros::{export};
use wasm_rpc::error::Error;
use ellipticoin::{SYSTEM_ADDRESS, Value};
use errors;

#[export]
mod caller {
    pub fn add(a: u64, b: u64) -> Result<u64, Error> {
        Ok(a + b)
    }

    pub fn call(
        contract_name: String,
        function: String,
        arguments: Value,
    ) -> Result<Value, Error> {
        let contract_address = [&SYSTEM_ADDRESS.to_vec(), contract_name.as_bytes()].concat();
        let (result_code, result_value) = ellipticoin::call(contract_address, &function, arguments.as_array().unwrap().to_vec());
        if result_code == 0 {
            Ok(result_value.into())
        } else {
            Err(errors::CONTRACT_CALL_ERROR.into())
        }
    }

    pub fn caller() -> Result<Value, Error> {
        Ok(ellipticoin::caller().into())
    }

    pub fn return_7() -> Result<Value, Error> {
        Ok((7 as i64).into())
    }
}
