use redis::Commands;

#[derive(Clone, Copy)]
pub enum StateType {
    Memory,
    Storage,
}
pub struct BlockIndex<'a> {
    pub redis: &'a redis::Connection,
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

    pub fn get_latest(&self, state_type: StateType, key: &[u8]) -> u64 {
        *self
            .redis
            .lrange::<_, Vec<u64>>(block_index_key(state_type, key), 0, 0)
            .expect("invalid block index")
            .get(0)
            .unwrap_or(&0)
    }
}
