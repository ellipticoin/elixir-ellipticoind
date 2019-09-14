pub use wasm_rpc::error::{Error, ErrorStruct};
pub const CONTRACT_CALL_ERROR: ErrorStruct<'static> = Error {
    code: 1,
    message: "Contract call error",
};
