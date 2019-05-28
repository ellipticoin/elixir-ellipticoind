use block_index::BlockIndex;
use redis::Commands;

fn memory_key(key: &[u8]) -> Vec<u8> {
    ["memory:".as_bytes().to_vec(), key.to_vec()].concat()
}
fn hash_key(block_number: u64, key: &[u8]) -> Vec<u8> {
    [u64_to_vec(block_number), key.to_vec()].concat()
}
fn u64_to_vec(n: u64) -> Vec<u8> {
    return unsafe { std::intrinsics::transmute::<u64, [u8; 8]>(n) }.to_vec();
}

fn get_memory_by_hash_key(conn: &redis::Connection, hash_key: &[u8]) -> Vec<u8> {
    let value: Vec<u8> = conn.hget("memory_hash", hash_key.to_vec()).unwrap();
    value
}

pub struct Memory<'a> {
    pub redis: &'a redis::Connection,
    pub block_index: &'a BlockIndex<'a>,
}

impl<'a> Memory<'a> {
    pub fn new(redis: &'a redis::Connection, block_index: &'a BlockIndex<'a>) -> Memory<'a> {
        Memory {
            redis: redis,
            block_index: block_index,
        }
    }
    pub fn set(&self, block_number: u64, key: &[u8], value: &[u8]) {
        let _: () = redis::pipe()
            .atomic()
            .cmd("SADD")
            .arg("memory_keys")
            .arg(memory_key(key))
            .ignore()
            .cmd("ZREM")
            .arg(memory_key(key))
            .arg(hash_key(block_number, key))
            .ignore()
            .cmd("ZADD")
            .arg(memory_key(key))
            .arg(block_number)
            .arg(block_number)
            .ignore()
            .cmd("HSET")
            .arg("memory_hash")
            .arg(hash_key(block_number, key))
            .arg(value)
            .ignore()
            .query(self.redis)
            .unwrap();
    }

    pub fn get(&self, key: &[u8]) -> Vec<u8> {
        let latest_hash_keys = self
            .redis
            .zrevrangebyscore_limit::<_, _, _, Vec<u64>>(memory_key(key), "+inf", "-inf", 0, 1)
            .unwrap();

        match latest_hash_keys.as_slice() {
            [block_number] => get_memory_by_hash_key(self.redis, &hash_key(*block_number, key)),
            _ => vec![],
        }
    }
}
