package main

import (
	"context"
	"fmt"

	"github.com/libp2p/go-libp2p-core/peer"
	multiaddr "github.com/multiformats/go-multiaddr"

	libp2p "github.com/libp2p/go-libp2p"
	core "github.com/libp2p/go-libp2p-core"
	"github.com/libp2p/go-libp2p-core/crypto"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
)

type libp2pPubSub struct {
	pubsub       *pubsub.PubSub       // PubSub of each individual node
	subscription *pubsub.Subscription // Subscription of individual node
	topic        string               // PubSub topic
}

// Broadcast Uses PubSub publish to broadcast messages to other peers
func (c *libp2pPubSub) Broadcast(msg []byte) {
	// Broadcasting to a topic in PubSub
	err := c.pubsub.Publish(c.topic, msg)
	if err != nil {
		fmt.Printf("Error : %v\n", err)
		return
	}
}

// Receive gets message from PubSub in a blocking way
func (c *libp2pPubSub) Receive() ([]byte, []byte) {
	// Blocking function for consuming newly received messages
	// We can access message here
	msg, _ := c.subscription.Next(context.Background())
	return msg.From, msg.Data
}

// createPeer creates a peer on localhost and configures it to use libp2p.
func (c *libp2pPubSub) createPeer(secretKey []byte, ip string, port int) *core.Host {
	// Creating a node
	h, err := createHost(secretKey, ip, port)
	if err != nil {
		panic(err)
	}

	// Returning pointer to the created host
	return &h
}

// initializePubSub creates a PubSub for the peer and also subscribes to a topic
func (c *libp2pPubSub) initializePubSub(h core.Host) {
	var err error
	// Creating pubsub
	// every peer has its own PubSub
	c.pubsub, err = applyPubSub(h)
	if err != nil {
		fmt.Printf("Error : %v\n", err)
		return
	}

	// Registering to the topic
	c.topic = "TOPIC"
	// Creating a subscription and subscribing to the topic
	c.subscription, err = c.pubsub.Subscribe(c.topic)
	if err != nil {
		fmt.Printf("Error : %v\n", err)
		return
	}

}

// createHost creates a host with some default options and a signing identity
func createHost(secretKey []byte, ip string, port int) (core.Host, error) {
	sk, err := crypto.UnmarshalEd25519PrivateKey(secretKey)
	//prvKey, _ := ecdsa.GenerateKey(btcec.S256(), rand.Reader)
        //sk := (*crypto.Secp256k1PrivateKey)(prvKey)
	// Starting a peer with default configs
	opts := []libp2p.Option{
		libp2p.ListenAddrStrings(fmt.Sprintf("/ip4/%s/tcp/%d", ip, port)),
		libp2p.Identity(sk),
		libp2p.DefaultTransports,
		libp2p.DefaultMuxers,
		libp2p.DefaultSecurity,
	}

	h, err := libp2p.New(context.Background(), opts...)
	if err != nil {
		return nil, err
	}

	return h, nil
}

// getLocalhostAddress is used for getting address of hosts
func getLocalhostAddress(h core.Host) string {
	for _, addr := range h.Addrs() {
		return addr.String() + "/p2p/" + h.ID().Pretty()
	}

	return ""
}

// applyPubSub creates a new GossipSub with message signing
func applyPubSub(h core.Host) (*pubsub.PubSub, error) {
	optsPS := []pubsub.Option{
		pubsub.WithMessageSigning(true),
	}

	return pubsub.NewGossipSub(context.Background(), h, optsPS...)
}

// connectHostToPeer is used for connecting a host to another peer
func connectHostToPeer(h core.Host, connectToAddress string) {
	// Creating multi address
	multiAddr, err := multiaddr.NewMultiaddr(connectToAddress)
	if err != nil {
		fmt.Printf("Error : %v\n", err)
		return
	}

	pInfo, err := peer.AddrInfoFromP2pAddr(multiAddr)
	if err != nil {
		fmt.Printf("Error : %v\n", err)
		return
	}

	err = h.Connect(context.Background(), *pInfo)
	if err != nil {
		fmt.Printf("Error : %v\n", err)
	}
}
