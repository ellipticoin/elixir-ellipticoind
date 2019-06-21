#![feature(
    proc_macro_hygiene,
    core_intrinsics,
    alloc_error_handler,
)]
extern crate alloc;
extern crate wasm_rpc;
extern crate wasm_rpc_macros;
extern crate wee_alloc;
#[cfg(not(test))]
extern crate ellipticoin;
#[cfg(test)]
extern crate mock_ellipticoin as ellipticoin;
#[cfg(test)]
extern crate serde_cbor;

#[global_allocator]
static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;
mod constructor;
