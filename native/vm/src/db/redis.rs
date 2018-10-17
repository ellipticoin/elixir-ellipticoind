use redis::Commands;
extern crate redis;
use db::DB;

impl DB for redis::Connection {
    fn write(&self, key: &[u8], value: &[u8]) {
        let _: () = redis::pipe()
            .atomic()
            .cmd("SET")
            .arg(key)
            .arg(value)
            .ignore()
            .cmd("RPUSH")
            .arg("state_changes")
            .arg(([&key[..], &value[..]]).concat())
            .ignore()
            .query(self)
            .unwrap();
    }

    fn read(&self, key: &[u8]) -> Vec<u8> {
        self.get(key).unwrap()
    }

    fn get_block_data(&self) -> Vec<u8> {
        let elements: Vec<Vec<u8>> = self.lrange("current_block", 0, -1).unwrap();
        elements.concat()
    }
}
