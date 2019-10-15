#![feature(rustc_private)]
extern crate serialize;
extern crate num_bigint;
extern crate num_traits;
extern crate sha2;
extern crate rand;
extern crate base64;

use rand::Rng;
use num_bigint::BigUint;
use sha2::{Sha256, Digest};
use num_traits::{ToPrimitive, FromPrimitive};
use std::{io, env::args, process, thread};
use std::io::BufRead;

const NUMERATOR_BYTE_LENGTH: usize = 8;

fn main() {
    let target_number_of_hashes = args().nth(1).unwrap().parse().unwrap();
    let mut line = String::new();
    let stdin = io::stdin();
    stdin.lock().read_line(&mut line).expect("Could not read line");
    exit_on_close();
    let data = base64::decode(&line.trim_end_matches("\n")).unwrap();
    // let mut rng = rand::thread_rng();
    // let random = rng.gen_range(0, 1000);
    // std::thread::sleep(std::time::Duration::from_millis(random));
    let nonce = hashfactor(data, target_number_of_hashes);
    println!("{}", nonce);
}

fn hashfactor(data: Vec<u8>, target_number_of_hashes: u64) -> u64 {
    let mut rng = rand::thread_rng();
    let mut nonce = rng.gen_range(0, target_number_of_hashes);
    let mut hash: Vec<u8>;
    let data_hash = sha256(data);

    loop {
        hash = hash_with_nonce(nonce, &data_hash);
        let value = first_bytes_as_u64(hash.clone());
        if is_factor_of(value, target_number_of_hashes + 1) {
            break;
        } else {
            nonce = nonce + 1;
        }
    }

    nonce
}

fn first_bytes_as_u64(hash: Vec<u8>) -> u64 {
    BigUint::from_bytes_le(&hash[..NUMERATOR_BYTE_LENGTH]).to_u64().unwrap()
}

fn is_factor_of(numerator: u64, denominator: u64) -> bool {
    numerator % denominator == 0
}

fn hash_with_nonce(nonce: u64, data: &[u8]) -> Vec<u8>{
    let nonce_big_uint: BigUint = BigUint::from_u64(nonce).unwrap();
    sha256([
           data.to_vec(),
           nonce_big_uint.to_bytes_le(),
    ].concat())
}

fn sha256(message: Vec<u8>) -> Vec<u8> {
    let mut hasher = Sha256::new();
    hasher.input(message);
    hasher.result().to_vec()
}

//
//  https://stackoverflow.com/a/39772976/1356670
// "When a process is exited (the port is closed) the spawned program / port should get an EOF on
// its STDIN. This is the "standard" way for the process to detect when the port has been closed:
// an end-of-file on STDIN."

fn exit_on_close() {
    thread::spawn(move || {
        let mut buffer = String::new();
        let bytes = io::stdin().read_line(&mut buffer).unwrap();
        if bytes == 0 {
            process::exit(0);
        }
    });
}
