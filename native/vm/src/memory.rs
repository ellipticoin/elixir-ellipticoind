use changeset::Changeset;
use helpers::u64_to_vec;
use redis::Commands;

#[derive(Clone, Copy)]
pub enum StateType {
    Memory,
    Storage,
}

const NAMESPACE: &str = "memory";
pub struct Memory {
    pub redis: redis::Connection,
    pub changeset: Changeset,
    pub working_changeset: Changeset,
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

impl Memory {
    pub fn new(redis: redis::Connection, changeset: Changeset) -> Self {
        Memory {
            redis,
            changeset,
            working_changeset: Changeset::new(),
        }
    }

    pub fn get(&self, key: &[u8]) -> Vec<u8> {
        self.get_cached(key)
            .unwrap_or(&self.get_from_memory(key))
            .to_vec()
    }

    pub fn get_from_memory(&self, key: &[u8]) -> Vec<u8> {
        let latest_block = self.get_latest(StateType::Memory, &key);
        let hash_key = [u64_to_vec(latest_block), key.to_vec()].concat();
        self.redis.hget(NAMESPACE, hash_key).unwrap()
    }

    pub fn get_cached(&self, key: &[u8]) -> Option<&Vec<u8>> {
        self.changeset.get(key)
    }

    pub fn set(&mut self, key: Vec<u8>, value: Vec<u8>) {
        self.working_changeset.insert(key, value);
    }

    pub fn commit(&mut self) {
        self.changeset.extend(self.working_changeset.clone());
        self.working_changeset = Changeset::new();
    }

    pub fn rollback(&mut self) {
        self.working_changeset = Changeset::new();
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
