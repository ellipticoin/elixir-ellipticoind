use std::mem::transmute;
const LENGTH_BYTE_COUNT: usize = 4;

// pub fn from_pointer_with_length(ptr: *const u8) -> Vec<u8> {
//     let length_slice = unsafe { slice::from_raw_parts(ptr.offset(0) as *const u8, LENGTH_BYTE_COUNT as usize) };
//     let mut length_u8 = [0 as u8; LENGTH_BYTE_COUNT];
//     length_u8.clone_from_slice(&length_slice);
//     let length: u32 = unsafe {transmute(length_u8)};
//
//     unsafe {
//         slice::from_raw_parts(ptr.offset(LENGTH_BYTE_COUNT as isize) as *const u8, length.to_be() as usize).to_vec()
//     }
// }

pub unsafe trait VecWithLength {
    fn to_vec_with_length(&self) -> Vec<u8>;
}

unsafe impl VecWithLength for Vec<u8> {
    fn to_vec_with_length(&self) -> Vec<u8> {
        let length_slice: [u8; LENGTH_BYTE_COUNT] = unsafe{ transmute::<u32, [u8; LENGTH_BYTE_COUNT]>((self.len() as u32).to_be()) };
        [&length_slice, &self[..]].concat()
    }
}
