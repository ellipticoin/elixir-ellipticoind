use rustler::types::{Binary, OwnedBinary};
use rustler::{Encoder, Env, Error, Term};
use sodiumoxide::crypto::sign::ed25519;
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
    let (pk, sk) = ed25519::gen_keypair();
    Ok((
        to_binary(pk.as_ref().to_vec()).release(env),
        to_binary(sk.as_ref().to_vec()).release(env),
    )
        .encode(env))
}

fn sign<'a>(env: Env<'a>, args: &[Term<'a>]) -> Result<Term<'a>, Error> {
    let message: Binary = args[0].decode()?;
    let private_key: Binary = args[1].decode()?;

    let signature: Vec<u8> = ed25519::sign(
        message.as_slice(),
        &ed25519::SecretKey::from_slice(private_key.as_slice()).unwrap(),
    );
    Ok((to_binary(signature[..signature.len() - message.len()].to_vec()).release(env)).encode(env))
}
fn valid_signature<'a>(env: Env<'a>, args: &[Term<'a>]) -> Result<Term<'a>, Error> {
    let signature: Binary = args[0].decode()?;
    let message: Binary = args[1].decode()?;
    let public_key: Binary = args[2].decode()?;
    &ed25519::Signature::from_slice(signature.as_slice()).unwrap();

    let valid = ed25519::verify_detached(
        &ed25519::Signature::from_slice(signature.as_slice()).unwrap(),
        message.as_slice(),
        &ed25519::PublicKey::from_slice(public_key.as_slice()).unwrap(),
    );
    Ok((valid).encode(env))
}

fn private_key_to_public_key<'a>(env: Env<'a>, args: &[Term<'a>]) -> Result<Term<'a>, Error> {
    let private_key: Binary = args[0].decode()?;

    Ok((to_binary(private_key[ed25519::PUBLICKEYBYTES..].to_vec()).release(env)).encode(env))
}

fn to_binary(vec: Vec<u8>) -> OwnedBinary {
    let mut binary = OwnedBinary::new(vec.len()).unwrap();
    let _ = binary.as_mut_slice().write_all(&vec);
    binary
}
