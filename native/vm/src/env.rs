use serde::{Deserialize, Serialize};
#[derive(Deserialize, Serialize, Clone, Debug)]
pub struct Env {
    pub block_number: u64,
    #[serde(with = "serde_bytes")]
    pub block_winner: Vec<u8>,
    #[serde(with = "serde_bytes")]
    pub block_hash: Vec<u8>,
    pub caller: Option<serde_bytes::ByteBuf>,
}
