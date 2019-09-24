use std::intrinsics::transmute;
use std::mem;

pub fn i32_to_vec(n: i32) -> Vec<u8> {
    unsafe { transmute::<i32, [u8; mem::size_of::<i32>()]>(n) }.to_vec()
}

pub fn u64_to_vec(n: u64) -> Vec<u8> {
    unsafe { transmute::<u64, [u8; mem::size_of::<u64>()]>(n) }.to_vec()
}

pub fn u32_to_vec(n: u32) -> Vec<u8> {
    unsafe { transmute::<u32, [u8; mem::size_of::<u32>()]>(n) }.to_vec()
}

pub fn right_pad_vec<T>(mut vec: Vec<T>, len: usize, pad: T) -> Vec<T>
where
    T: Copy,
{
    while vec.len() < len {
        vec.push(pad);
    }
    vec
}
