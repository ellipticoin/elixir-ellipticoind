use wasm_rpc::Error;
use ellipticoin::{
    read_int,
    write_int,
};

pub fn increment_by(n: u64) -> Result<(), Error> {
    let count = read_int("counter");
    write_int("counter", count + n);
    Ok(())
}

pub fn get_count() -> Result<u64, Error> {
    let count = read_int("counter");
    Ok(count)
}
