use block_index::{BlockIndex, StateType};
use redis::Commands;

const REDIS_KEY: &str = "memory";

fn hash_key(block_number: u64, key: &[u8]) -> Vec<u8> {
    [u64_to_vec(block_number), key.to_vec()].concat()
}

fn u64_to_vec(n: u64) -> Vec<u8> {
    return unsafe { std::intrinsics::transmute::<u64, [u8; 8]>(n) }.to_vec();
}

pub struct Memory<'a> {
    pub redis: &'a redis::Connection,
    pub block_index: &'a BlockIndex<'a>,
    pub namespace: Vec<u8>,
}

impl<'a> Memory<'a> {
    pub fn new(
        redis: &'a redis::Connection,
        block_index: &'a BlockIndex<'a>,
        namespace: Vec<u8>
        ) -> Memory<'a> {
        Memory {
            redis: redis,
            block_index: block_index,
            namespace: namespace,
        }
    }

    pub fn namespaced_key(&self, key: &[u8]) -> Vec<u8>{
        [self.namespace.clone(), key.to_vec()].concat()
    }

    pub fn get(&self, key: &[u8]) -> Vec<u8> {
        let latest_block = self.block_index.get_latest(StateType::Memory, &self.namespaced_key(key));
        self.redis
            .hget(REDIS_KEY, hash_key(latest_block, &self.namespaced_key(key)))
            .unwrap()
    }
}
