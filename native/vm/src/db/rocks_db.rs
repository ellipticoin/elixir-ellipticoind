extern crate rocksdb;
use std::sync::RwLockWriteGuard;
use db::DB;
// use std::ops::Deref;
// use std::sync::{RwLock,Arc};

impl<'a> DB for RwLockWriteGuard<'a, rocksdb::DB> {
    fn write(&self, key: &[u8], value: &[u8]) {
        self.put(key, value).expect("failed to write");
    }

    fn read(&self, key: &[u8]) -> Vec<u8> {
        match self.get(key) {
            Ok(Some(value)) => value.to_vec(),
            Ok(None) => vec![],
            Err(e) => panic!(e),
        }
    }

    fn get_block_data(&self) -> Vec<u8> {
        vec![]
    }
}

// pub struct RocksDBHandle {
//     pub db: Arc<RwLock<rocksdb::DB>>,
// }
//
// impl Deref for RocksDBHandle {
//     type Target = Arc<RwLock<rocksdb::DB>>;
//
//     fn deref(&self) -> &Self::Target { &self.db }
// }
