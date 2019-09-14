use block_index::{BlockIndex, StateType};
use changeset::Changeset;
use helpers::u64_to_vec;
use rocksdb::ops::Get;

pub struct Storage<'a> {
    pub rocksdb: &'a rocksdb::ReadOnlyDB,
    pub block_index: &'a BlockIndex<'a>,
    pub changeset: &'a mut Changeset,
    pub working_changeset: Changeset,
}

impl<'a> Storage<'a> {
    pub fn new(
        rocksdb: &'a rocksdb::ReadOnlyDB,
        block_index: &'a BlockIndex<'a>,
        changeset: &'a mut Changeset,
    ) -> Storage<'a> {
        Storage {
            rocksdb,
            block_index,
            changeset,
            working_changeset: Changeset::new(),
        }
    }

    pub fn get(&self, key: &[u8]) -> Vec<u8> {
        self.get_cached(key)
            .unwrap_or(&self.get_from_storage(key))
            .to_vec()
    }

    pub fn get_cached(&self, key: &[u8]) -> Option<&Vec<u8>> {
        self.changeset
            .get(key)
    }

    pub fn get_from_storage(&self, key: &[u8]) -> Vec<u8> {
        let latest_block = self
            .block_index
            .get_latest(StateType::Storage, &key);
        let hash_key = [u64_to_vec(latest_block), key.to_vec()].concat();
        match self.rocksdb.get(hash_key) {
            Ok(Some(value)) => value.to_vec(),
            Ok(None) => vec![],
            Err(e) => panic!(e),
        }
    }

    pub fn set(&mut self, key: Vec<u8>, value: Vec<u8>) {
        self.working_changeset
            .insert(key, value);
    }

    pub fn commit(&mut self) {
        self.changeset.extend(self.working_changeset.clone());
        self.working_changeset = Changeset::new();
    }

    pub fn rollback(&mut self) {
        self.working_changeset = Changeset::new();
    }
}
