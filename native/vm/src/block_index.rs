pub struct BlockIndex<'a> {
    pub redis: &'a redis::Connection,
}

impl<'a> BlockIndex<'a> {
    pub fn new(
        redis: &'a redis::Connection,
    ) -> BlockIndex<'a> {
        BlockIndex {
            redis: redis,
        }
    }
}
