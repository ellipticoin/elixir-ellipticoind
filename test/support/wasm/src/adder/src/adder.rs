use wasm_rpc::Error;

pub fn add(a: u32, b: u32) -> Result<u32, Error> {
    Ok(a + b)
}
