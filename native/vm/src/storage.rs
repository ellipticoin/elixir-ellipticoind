use block_index::{BlockIndex, StateType};
use rocksdb::ops::Get;

fn hash_key(block_number: u64, key: &[u8]) -> Vec<u8> {
    [u64_to_vec(block_number), key.to_vec()].concat()
}

fn u64_to_vec(n: u64) -> Vec<u8> {
    return unsafe { std::intrinsics::transmute::<u64, [u8; 8]>(n) }.to_vec();
}

pub struct Storage<'a> {
    pub rocksdb: &'a rocksdb::ReadOnlyDB,
    pub block_index: &'a BlockIndex<'a>,
    pub namespace: Vec<u8>,
}

impl<'a> Storage<'a> {
    pub fn new(
        rocksdb: &'a rocksdb::ReadOnlyDB,
        block_index: &'a BlockIndex<'a>,
        namespace: Vec<u8>
        ) -> Storage<'a> {
        Storage {
            rocksdb: rocksdb,
            block_index: block_index,
            namespace: namespace,
        }
    }
    pub fn namespaced_key(&self, key: &[u8]) -> Vec<u8>{
        [self.namespace.clone(), key.to_vec()].concat()
    }

    pub fn get(&self, key: &[u8]) -> Vec<u8> {
        let latest_block = self.block_index.get_latest(StateType::Storage, &self.namespaced_key(key));
        match self.rocksdb
            .get(hash_key(latest_block, &self.namespaced_key(key))) {
                Ok(Some(value)) => value.to_vec(),
                Ok(None) => vec![],
                Err(e) => panic!(e),
            }
    }
}
