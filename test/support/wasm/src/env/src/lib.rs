#![feature(
    proc_macro_hygiene,
    core_intrinsics,
    alloc_error_handler,
)]
extern crate alloc;
extern crate wasm_rpc;
extern crate wasm_rpc_macros;
extern crate wee_alloc;
extern crate ellipticoin;

#[global_allocator]
static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;
mod env;
