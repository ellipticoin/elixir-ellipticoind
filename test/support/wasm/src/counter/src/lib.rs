#![no_std]
#![feature(
    core_intrinsics,
    alloc,
    alloc_error_handler,
    proc_macro_mod,
    proc_macro_gen,
)]
extern crate alloc;
#[macro_use]
extern crate wasm_rpc;
extern crate wasm_rpc_macros;
extern crate wee_alloc;
extern crate ellipticoin;

#[global_allocator]
static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;
use self::wasm_rpc_macros::export;

#[export]
mod counter;
