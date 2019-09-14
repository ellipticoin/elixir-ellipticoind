#![feature(proc_macro_hygiene)]
extern crate ellipticoin;
extern crate alloc;
extern crate wasm_rpc;
extern crate wasm_rpc_macros;
extern crate wee_alloc;

#[global_allocator]
static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;
mod caller;
mod errors;
