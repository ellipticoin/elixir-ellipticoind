package main

import (
	"bufio"
	"context"
	"encoding/binary"
	"encoding/hex"
	"flag"
	"fmt"
	"io"
	"os"
	"reflect"
	"strconv"
	"time"

	core "github.com/libp2p/go-libp2p-core"
	"github.com/libp2p/go-libp2p-core/peer"
	multiaddr "github.com/multiformats/go-multiaddr"
)

func log(format string, args ...interface{}) {
	message := fmt.Sprintf(format, args...)
	writeMessage([]byte("log:" + message))
}

func writeMessage(bytes []byte) {
	b := make([]byte, 4)
	binary.BigEndian.PutUint32(b[0:], uint32(len(bytes)))
	os.Stdout.Write(b)
	os.Stdout.Write(bytes)
}

func createPubSub(secretKey []byte, ip string, port int, bootnodes []string) (*libp2pPubSub, *core.Host) {
	pubsub := new(libp2pPubSub)
	host := pubsub.createPeer(secretKey, ip, port)
	pubsub.initializePubSub(*host)
	log("Started: %s", getLocalhostAddress(*host))

	for _, bootnode := range bootnodes {
		multiAddr, _ := multiaddr.NewMultiaddr(bootnode)
		pInfo, _ := peer.AddrInfoFromP2pAddr(multiAddr)
		log("Connecting to : %s", bootnode)
		err := (*host).Connect(context.Background(), *pInfo)
		if err != nil {
			log("%s", err)
		}

		time.Sleep(time.Second * 2)
	}
	writeMessage([]byte("started"))
	return pubsub, host
}

func receiveMessages(pubsub *libp2pPubSub, host *core.Host) {
	for {
		from, msg := pubsub.Receive()
		if !reflect.DeepEqual(from, []byte((*host).ID())) {
			writeMessage([]byte("message:" + string(msg)))
		}
	}
}

func sendMessages(pubsub *libp2pPubSub, host *core.Host) {
	reader := bufio.NewReader(os.Stdin)
	for {
		msg := readMessage(reader)
		pubsub.Broadcast(msg)
		time.Sleep(time.Second * 1)
	}
}

func main() {
	flag.Parse()
	secretKey, _ := hex.DecodeString(flag.Args()[0])
	ip := flag.Args()[1]
	port, _ := strconv.Atoi(flag.Args()[2])
	bootnodes := flag.Args()[3:]
	log("incomming len: %d", len(secretKey))

	pubsub, host := createPubSub(secretKey, ip, port, bootnodes)

	go sendMessages(pubsub, host)
	receiveMessages(pubsub, host)
}

func readMessage(reader io.Reader) []byte {
	byteLengthBuf := make([]byte, 4)
	reader.Read(byteLengthBuf)
	byteLength := binary.BigEndian.Uint32(byteLengthBuf)
	buf := make([]byte, byteLength)
	io.ReadFull(reader, buf)
	return buf

}
