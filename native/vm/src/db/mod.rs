pub mod redis;

pub trait DB {
    fn write(&self, key: &[u8], value: &[u8]);
    fn read(&self, key: &[u8]) -> Vec<u8>;
    fn get_block_data(&self) -> Vec<u8>;
}
