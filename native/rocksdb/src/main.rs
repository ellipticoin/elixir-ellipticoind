#[macro_use]
extern crate lazy_static;
extern crate rocksdb;
use std::io::{self, BufRead};
use rocksdb::ops::{Get, Put};
use std::env::args;
use rocksdb::{ReadOnlyDB, DB};
use rocksdb::ops::Open;
use std::thread;

lazy_static! {
    static ref ROCKSDB: rocksdb::DB = {
        rocksdb()
    };

    static ref READ_ONLY_ROCKSDB: rocksdb::ReadOnlyDB = {
        ReadOnlyDB::open_default(args().nth(1).unwrap().as_str()).unwrap()
    };
}

fn rocksdb() -> rocksdb::DB {
    loop {
        match DB::open_default(args().nth(1).unwrap().as_str()) {
            Err(_e) => (),
            Ok(db) => { return db }
        }
        thread::sleep(std::time::Duration::from_millis(500))
    };
}

fn main() {
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        match line
            .unwrap()
            .split(" ")
            .collect::<Vec<&str>>()
            .as_slice() {
                ["put", key, value] => put(
                    base64::decode(key).unwrap(),
                    base64::decode(value).unwrap(),
                ),
                ["get", key] =>  get(base64::decode(key).unwrap()),
                _ => panic!("invalid command"),
        }
    }
}

fn put(key: Vec<u8>, value: Vec<u8>) {
    {
        ROCKSDB.put(key, value).unwrap();
        println!("ok");
    }
}

fn get(key: Vec<u8>) {
    let result = ROCKSDB.get(key);
    match result.unwrap() {
        Some(value) => println!("{}", base64::encode(&value)),
        None => println!("{}", base64::encode(&vec![123])),
    }
}
