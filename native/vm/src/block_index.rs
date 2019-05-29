use redis::Commands;
pub struct BlockIndex<'a> {
    pub redis: &'a redis::Connection,
}

fn memory_key(key: &[u8]) -> Vec<u8> {
    ["memory:".as_bytes().to_vec(), key.to_vec()].concat()
}

impl<'a> BlockIndex<'a> {
    pub fn new(redis: &'a redis::Connection) -> BlockIndex<'a> {
        BlockIndex { redis: redis }
    }

    pub fn add(&self, block_number: u64, key: &[u8]) {
        let () = redis::pipe()
            .atomic()
            .cmd("SADD")
            .arg("memory_keys")
            .arg(memory_key(key))
            .ignore()
            .cmd("ZREM")
            .arg(memory_key(key))
            .arg(block_number)
            .ignore()
            .cmd("ZADD")
            .arg(memory_key(key))
            .arg(block_number)
            .arg(block_number)
            .ignore()
            .query(self.redis)
            .unwrap();
    }

    pub fn get_latest(&self, key: &[u8]) -> u64 {
        let latest_hash_keys = self
            .redis
            .zrevrangebyscore_limit::<_, _, _, Vec<u64>>(memory_key(key), "+inf", "-inf", 0, 1)
            .unwrap();

        match latest_hash_keys.as_slice() {
            [block_number] => *block_number,
            _ => 0,
        }
    }
}
