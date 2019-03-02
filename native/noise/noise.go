package main

import (
	"bufio"
	"encoding/base64"
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/perlin-network/noise"
	"github.com/perlin-network/noise/cipher/aead"
	"github.com/perlin-network/noise/handshake/ecdh"
	"github.com/perlin-network/noise/log"
	"github.com/perlin-network/noise/payload"
	"github.com/perlin-network/noise/protocol"
	"github.com/perlin-network/noise/skademlia"
	"github.com/pkg/errors"
)

var (
	opcodeMessage noise.Opcode
)

type message struct {
	bytes []byte
}

func (message) Read(reader payload.Reader) (noise.Message, error) {
	bytes, err := reader.ReadBytes()
	if err != nil {
		return nil, errors.Wrap(err, "failed to read chat msg")
	}

	return message{
		bytes: bytes,
	}, nil
}

func (m message) Write() []byte {
	return payload.NewWriter(nil).WriteBytes(m.bytes).Bytes()
}

func setup(node *noise.Node) {
	opcodeMessage = noise.RegisterMessage(noise.NextAvailableOpcode(), (*message)(nil))

	node.OnPeerInit(func(node *noise.Node, peer *noise.Peer) error {
		go func() {
			for {
				msg := <-peer.Receive(opcodeMessage)
				bytes, err := payload.NewReader(msg.Write()).ReadBytes()
				if err != nil {
					panic(err)
				}

				fmt.Printf(
					"message:%s:%s\n", "",
					base64.StdEncoding.EncodeToString(bytes))
			}
		}()

		return nil
	})

}

func main() {
	log.Disable()
	hostFlag := flag.String("h", "127.0.0.1", "host to listen for peers on")
	portFlag := flag.Uint("p", 3000, "port to listen for peers on")
	flag.Parse()

	params := noise.DefaultParams()
	//params.NAT = nat.NewPMP()
	params.Keys = skademlia.RandomKeys()
	params.Host = *hostFlag
	params.Port = uint16(*portFlag)

	node, err := noise.NewNode(params)
	if err != nil {
		panic(err)
	}
	defer node.Kill()

	p := protocol.New()
	p.Register(ecdh.New())
	p.Register(aead.New())
	p.Register(skademlia.New())
	p.Enforce(node)

	setup(node)
	go node.Listen()
	// Wait for the server to boot.
	// TODO add this as a hook in `noise`
	time.Sleep(100 * time.Millisecond)
	println("started")

	if len(flag.Args()) > 0 {
		for _, address := range flag.Args() {
			peer, err := node.Dial(address)
			if err == nil {
				skademlia.WaitUntilAuthenticated(peer)
			}
		}
	}

	reader := bufio.NewReader(os.Stdin)

	for {
		txt, err := reader.ReadString('\n')

		if err != nil {
			panic(err)
		}

		decoded, err := base64.StdEncoding.DecodeString(txt)

		if err != nil {
			panic(err)
		}

		skademlia.BroadcastAsync(node, message{
			bytes: decoded,
		})
	}
}
