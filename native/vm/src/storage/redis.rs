use redis::Commands;
extern crate redis;
use storage::Storage;

fn storage_key(key: &[u8]) -> Vec<u8> {
    ["storage:".as_bytes().to_vec(), key.to_vec()].concat()
}
fn hash_key(block_number: u64, key: &[u8]) -> Vec<u8> {
    [
        u64_to_vec(block_number),
        key.to_vec(),
    ]
    .concat()
}
fn u64_to_vec(n: u64) -> Vec<u8> {
    return unsafe { std::intrinsics::transmute::<u64, [u8; 8]>(n) }.to_vec()
}

fn get_storage_by_hash_key(conn: &redis::Connection, hash_key: &[u8]) -> Vec<u8> {
    let value: Vec<u8> = conn.hget("storage_hash", hash_key.to_vec()).unwrap();
    value
}

impl Storage for redis::Connection {
    fn write(&self, block_number: u64, key: &[u8], value: &[u8]) {
        let _: () = redis::pipe()
            .atomic()
            .cmd("SADD")
            .arg("storage_keys")
            .arg(storage_key(key))
            .ignore()
            .cmd("ZREM")
            .arg(storage_key(key))
            .arg(hash_key(block_number, key))
            .ignore()
            .cmd("ZADD")
            .arg(storage_key(key))
            .arg(block_number)
            .arg(block_number)
            .ignore()
            .cmd("HSET")
            .arg("storage_hash")
            .arg(hash_key(block_number, key))
            .arg(value)
            .ignore()
            .query(self)
            .unwrap();
    }

    fn read(&self, key: &[u8]) -> Vec<u8> {
        let latest_hash_keys = self
            .zrevrangebyscore_limit::<_, _, _, Vec<u64>>(storage_key(key), "+inf", "-inf", 0, 1)
            .unwrap();

        match latest_hash_keys.as_slice() {
            [block_number] => {
                get_storage_by_hash_key(self, &hash_key(*block_number, key))
            },
            _ => vec![],
        }
    }
}
