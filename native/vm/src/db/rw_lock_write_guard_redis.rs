use redis::Commands;
extern crate redis;
use std::sync::{RwLockWriteGuard,RwLock,Arc};
use std::ops::Deref;
use db::DB;

impl<'a> DB for RwLockWriteGuard<'a, redis::Client> {
    fn write(&self, key: &[u8], value: &[u8]) {
        let conn = self.get_connection().unwrap();
        let _ : () = redis::pipe()
                            .atomic()
                            .cmd("SET").arg(key).arg(value).ignore()
                            .cmd("RPUSH").arg("state_changes").arg(([&key[..], &value[..]]).concat()).ignore()
                            .query(&conn).unwrap();
    }

    fn read(&self, key: &[u8]) -> Vec<u8> {
        let conn = self.get_connection().unwrap();
        conn.get(key).unwrap()
    }

    fn get_block_data(&self) -> Vec<u8> {
        let conn = self.get_connection().unwrap();
        let elements: Vec<Vec<u8>> = conn.lrange("current_block", 0, -1).unwrap();
        elements.concat()
    }
}

pub struct RedisHandle {
    pub db: Arc<RwLock<redis::Client>>,
}

impl Deref for RedisHandle {
    type Target = Arc<RwLock<redis::Client>>;

    fn deref(&self) -> &Self::Target { &self.db }
}
