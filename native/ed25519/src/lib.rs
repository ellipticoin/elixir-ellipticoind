extern crate rand;
extern crate ed25519_dalek;

use sha2::Sha512;
use rand::rngs::OsRng;
use ed25519_dalek::{Keypair, PublicKey};
use ed25519_dalek::Signature;
use rustler::types::{Binary, OwnedBinary};
use rustler::{Encoder, Env, Error, Term};
use std::io::Write;

mod atoms {
    rustler::rustler_atoms! {
        atom ok;
    }
}

rustler::rustler_export_nifs!(
    "Elixir.Crypto.Ed25519",
    [
        ("keypair", 0, keypair),
        ("sign", 2, sign),
        ("valid_signature", 3, valid_signature),
        ("private_key_to_public_key", 1, private_key_to_public_key),
    ],
    None
);

fn keypair<'a>(env: Env<'a>, _args: &[Term<'a>]) -> Result<Term<'a>, Error> {
    let mut csprng: OsRng = OsRng::new().unwrap();
let keypair: Keypair = Keypair::generate::<Sha512, _>(&mut csprng);

    Ok((
        to_binary(keypair.public.as_bytes().to_vec()).release(env),
        to_binary(keypair.to_bytes().to_vec()).release(env),
    )
        .encode(env))
}

fn sign<'a>(env: Env<'a>, args: &[Term<'a>]) -> Result<Term<'a>, Error> {
    let message: Binary = args[0].decode()?;
    let keypair_binary: Binary = args[1].decode()?;
    let keypair = Keypair::from_bytes(keypair_binary.as_ref()).unwrap();
    let signature = keypair.sign::<Sha512>(message.as_ref());

    Ok((to_binary(signature.to_bytes().to_vec()).release(env)).encode(env))
}
fn valid_signature<'a>(env: Env<'a>, args: &[Term<'a>]) -> Result<Term<'a>, Error> {
    let signature_binary: Binary = args[0].decode()?;
    let message: Binary = args[1].decode()?;
    let public_key: Binary = args[2].decode()?;

    let signature = Signature::from_bytes(signature_binary.as_ref()).unwrap();
    let public_key = PublicKey::from_bytes(public_key.as_ref()).unwrap();
    let valid = public_key.verify::<Sha512>(message.as_ref(), &signature).is_ok();

    Ok((valid).encode(env))
}

fn private_key_to_public_key<'a>(env: Env<'a>, args: &[Term<'a>]) -> Result<Term<'a>, Error> {
    let keypair_binary: Binary = args[0].decode()?;
    let keypair = Keypair::from_bytes(keypair_binary.as_ref()).unwrap();

    Ok((to_binary(keypair.public.as_bytes().to_vec()).release(env)).encode(env))
}

fn to_binary(vec: Vec<u8>) -> OwnedBinary {
    let mut binary = OwnedBinary::new(vec.len()).unwrap();
    let _ = binary.as_mut_slice().write_all(&vec);
    binary
}
