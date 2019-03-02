#![feature(rustc_private)]
extern crate rustc_serialize;
extern crate fred;
extern crate futures;
extern crate libp2p;
extern crate rand;
extern crate redis;
extern crate redis_async;
extern crate tokio;
extern crate tokio_core;
extern crate tokio_stdin_stdout;
extern crate tokio_timer_patched as tokio_timer;
use futures::stream::{Stream};
use futures::{Async};
use rustc_serialize::base64::FromBase64;
use std::process;
use libp2p::{
    PeerId,
    Multiaddr,
    NetworkBehaviour,
    secio,
    core::PublicKey,
    tokio_codec::{FramedRead, LinesCodec}
};

fn main() {
    start_server();
}

fn start_server() {
    env_logger::init();

    // Create a random PeerId
    let private_key = std::env::args()
        .nth(1)
        .unwrap()
        .from_base64()
        .unwrap();

    // libsodium's private_key is actually a the private_key concatenated
    // with the public key.
    let private_key_raw = &private_key[..32];
    let local_key = secio::SecioKeyPair::ed25519_raw_key(private_key_raw).unwrap();

    let local_peer_id = local_key.to_peer_id();

    // Set up a an encrypted DNS-enabled TCP Transport over the Mplex and Yamux protocols
    let transport = libp2p::build_development_transport(local_key);

    // Create a Floodsub topic
    let floodsub_topic = libp2p::floodsub::TopicBuilder::new("chat").build();

    // We create a custom network behaviour that combines floodsub and mDNS.
    // In the future, we want to improve libp2p to make this easier to do.
    #[derive(NetworkBehaviour)]
    struct MyBehaviour<TSubstream: libp2p::tokio_io::AsyncRead + libp2p::tokio_io::AsyncWrite> {
        floodsub: libp2p::floodsub::Floodsub<TSubstream>,
        mdns: libp2p::mdns::Mdns<TSubstream>,
        // kademlia: libp2p::kad::Kademlia<TSubstream>,
    }

    impl<TSubstream: libp2p::tokio_io::AsyncRead + libp2p::tokio_io::AsyncWrite>
        libp2p::core::swarm::NetworkBehaviourEventProcess<libp2p::mdns::MdnsEvent>
        for MyBehaviour<TSubstream>
    {
        fn inject_event(&mut self, event: libp2p::mdns::MdnsEvent) {
            match event {
                libp2p::mdns::MdnsEvent::Discovered(list) => {
                    for (peer, _) in list {
                        self.floodsub.add_node_to_partial_view(peer);
                    }
                }
                libp2p::mdns::MdnsEvent::Expired(list) => {
                    for (peer, _) in list {
                        if !self.mdns.has_node(&peer) {
                            self.floodsub.remove_node_from_partial_view(&peer);
                        }
                    }
                }
            }
        }
    }

    impl<TSubstream: libp2p::tokio_io::AsyncRead + libp2p::tokio_io::AsyncWrite>
        libp2p::core::swarm::NetworkBehaviourEventProcess<libp2p::floodsub::FloodsubEvent>
        for MyBehaviour<TSubstream>
    {
        // Called when `floodsub` produces an event.
        fn inject_event(&mut self, message: libp2p::floodsub::FloodsubEvent) {
            match message {
                libp2p::floodsub::FloodsubEvent::Message(message) => {
                    println!(
                        "message:{}:{}",
                        message.source.to_base58(),
                        &String::from_utf8_lossy(&message.data),
                    );
                },
                libp2p::floodsub::FloodsubEvent::Subscribed{..} => {
                    println!("started");
                }
                _ => {}
            }
        }
    }

    let bootnodes_string = std::env::args().nth(3).unwrap();
    let bootnodes: Vec<(PeerId, Multiaddr)> = if bootnodes_string == "" {
        vec![]
    } else {
        bootnodes_string.split(",").map(|string| {
            let bootnode_parts: Vec<&str> = string
                .split(":")
                .collect();

            if let &[peer_id_string, multi_addr_string] = bootnode_parts.as_slice() {
                let public_key: PublicKey = PublicKey::Ed25519(peer_id_string.from_base64().unwrap());
                let peer_id: PeerId = public_key.into_peer_id();
                let multi_addr: Multiaddr = multi_addr_string.parse().unwrap();
                (peer_id, multi_addr)
            } else {
                (PeerId::from_bytes(vec![0; 32]).unwrap(), Multiaddr::empty())
            }
        }).collect()
    };


    let _kademlia: libp2p::kad::Kademlia<String> = libp2p::kad::Kademlia::without_init(local_peer_id.clone());

    // Create a Swarm to manage peers and events
    let mut swarm = {
        let mut behaviour = MyBehaviour {
            floodsub: libp2p::floodsub::Floodsub::new(local_peer_id.clone()),
            mdns: libp2p::mdns::Mdns::new().expect("Failed to create mDNS service"),
            // kademlia: kademlia,
        };

        behaviour.floodsub.subscribe(floodsub_topic.clone());
        libp2p::Swarm::new(transport, behaviour, local_peer_id)
    };
    for (_peer_id, multi_addr) in bootnodes {
        libp2p::Swarm::dial_addr(&mut swarm, multi_addr).unwrap();
    };

    // Listen on all interfaces and whatever port the OS assigns
    let _addr = libp2p::Swarm::listen_on(
        &mut swarm,
        std::env::args().nth(2).unwrap().parse().unwrap(),
    )
    .unwrap();


    // Read full lines from stdin
    let stdin = tokio_stdin_stdout::stdin(0);
    let mut framed_stdin = FramedRead::new(stdin, LinesCodec::new());

    tokio::run(futures::future::poll_fn(move || -> Result<_, ()> {
        loop {
            match framed_stdin.poll().expect("Error while polling stdin") {
                Async::Ready(Some(line)) => {
                    swarm.floodsub.publish(&floodsub_topic, line.as_bytes());
                },
                Async::Ready(None) => process::exit(0),
                Async::NotReady => break,
            };
        }

        loop {
            match swarm.poll().expect("Error while polling swarm") {
                Async::Ready(_) => {},
                Async::NotReady => break,
            }
        }

        Ok(Async::NotReady)
    }));
}
