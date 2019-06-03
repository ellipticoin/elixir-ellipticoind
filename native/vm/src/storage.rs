use block_index::{BlockIndex, StateType};
use rocksdb::ops::{Get, Put};

fn hash_key(block_number: u64, key: &[u8]) -> Vec<u8> {
    [u64_to_vec(block_number), key.to_vec()].concat()
}

fn u64_to_vec(n: u64) -> Vec<u8> {
    return unsafe { std::intrinsics::transmute::<u64, [u8; 8]>(n) }.to_vec();
}

pub struct Storage<'a> {
    pub rocksdb: &'a rocksdb::DB,
    pub block_index: &'a BlockIndex<'a>,
}

impl<'a> Storage<'a> {
    pub fn new(rocksdb: &'a rocksdb::DB, block_index: &'a BlockIndex<'a>) -> Storage<'a> {
        Storage {
            rocksdb: rocksdb,
            block_index: block_index,
        }
    }
    pub fn set(&self, block_number: u64, key: &[u8], value: &[u8]) {
        self.block_index.add(StateType::Storage, block_number, key);
        let _: () = self
            .rocksdb
            .put(hash_key(block_number, key), value)
            .unwrap();
    }

    pub fn get(&self, key: &[u8]) -> Vec<u8> {
        let latest_block = self.block_index.get_latest(StateType::Storage, key);
        match self.rocksdb
            .get(hash_key(latest_block, key)) {
                Ok(Some(value)) => value.to_vec(),
                Ok(None) => vec![],
                Err(e) => panic!(e),
            }
        
    }
}
