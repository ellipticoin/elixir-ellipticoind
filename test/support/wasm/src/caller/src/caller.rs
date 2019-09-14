use wasm_rpc_macros::{export};
use wasm_rpc::error::Error;
use ellipticoin::{Contract, SYSTEM_ADDRESS, Value};
use errors;

extern "C" {
    fn __call(
        contract_deployer: *const u8,
        contract_name: *const u8,
        function_name: *const u8,
        arguments: *const u8,
    ) -> *const u8;
}
#[export]
mod caller {
    pub fn call(
        contract_name: String,
        function: String,
        arguments: Value,
    ) -> Result<Value, Error> {
        let contract = Contract::new(SYSTEM_ADDRESS.to_vec(), &contract_name);
        let (result_code, result_value) = contract.call(&function, arguments.as_array().unwrap().to_vec());
        if result_code == 0 {
            Ok(result_value.into())
        } else {
            Err(errors::CONTRACT_CALL_ERROR.into())
        }
    }
}
