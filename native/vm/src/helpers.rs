use std::mem::transmute;
pub const LENGTH_BYTE_COUNT: usize = 4;

pub unsafe trait VecWithLength {
    fn to_vec_with_length(&self) -> Vec<u8>;
}

unsafe impl VecWithLength for Vec<u8> {
    fn to_vec_with_length(&self) -> Vec<u8> {
        let length_slice: [u8; LENGTH_BYTE_COUNT] = unsafe{ transmute::<u32, [u8; LENGTH_BYTE_COUNT]>((self.len() as u32).to_be()) };
        [&length_slice, &self[..]].concat()
    }
}
