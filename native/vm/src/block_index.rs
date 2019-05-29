use redis::Commands;

#[derive(Clone, Copy)]
pub enum StateType {
    Memory,
    Storage,
}
pub struct BlockIndex<'a> {
    pub redis: &'a redis::Connection,
}

fn block_set_key(state_type: StateType) -> Vec<u8> {
    [
        state_type_to_string(state_type).as_bytes().to_vec(),
        "_keys".as_bytes().to_vec(),
    ]
    .concat()
}

fn block_index_key(state_type: StateType, key: &[u8]) -> Vec<u8> {
    [
        state_type_to_string(state_type).as_bytes().to_vec(),
        ":".as_bytes().to_vec(),
        key.to_vec(),
    ]
    .concat()
}

fn state_type_to_string(state_type: StateType) -> &'static str {
    match state_type {
        StateType::Memory => "memory",
        StateType::Storage => "storage",
    }
}

impl<'a> BlockIndex<'a> {
    pub fn new(redis: &'a redis::Connection) -> BlockIndex<'a> {
        BlockIndex { redis: redis }
    }

    pub fn add(&self, state_type: StateType, block_number: u64, key: &[u8]) {
        let () = redis::pipe()
            .atomic()
            .cmd("SADD")
            .arg(block_set_key(state_type))
            .arg(block_index_key(state_type, key))
            .ignore()
            .cmd("ZREM")
            .arg(block_index_key(state_type, key))
            .arg(block_number)
            .ignore()
            .cmd("ZADD")
            .arg(block_index_key(state_type, key))
            .arg(block_number)
            .arg(block_number)
            .ignore()
            .query(self.redis)
            .unwrap();
    }

    pub fn get_latest(&self, state_type: StateType, key: &[u8]) -> u64 {
        let latest_hash_keys = self
            .redis
            .zrevrangebyscore_limit::<_, _, _, Vec<u64>>(
                block_index_key(state_type, key),
                "+inf",
                "-inf",
                0,
                1,
            )
            .unwrap();

        match latest_hash_keys.as_slice() {
            [block_number] => *block_number,
            _ => 0,
        }
    }
}
