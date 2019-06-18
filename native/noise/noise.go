// Copyright (c) 2019 Perlin
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
// the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

package main

import (
	"bufio"
	"encoding/base64"
	"flag"
	"fmt"
	"net"
	"os"
	reflect "reflect"
	"strconv"
	strings "strings"
	"time"

	"github.com/perlin-network/noise"
	"github.com/perlin-network/noise/cipher"
	"github.com/perlin-network/noise/handshake"
	"github.com/perlin-network/noise/skademlia"
	"golang.org/x/net/context"
	"google.golang.org/grpc/peer"
)

type chatHandler struct{}

func (chatHandler) Stream(stream Ellipticoin_StreamServer) error {
	for {
		txt, _ := stream.Recv()

		p, ok := peer.FromContext(stream.Context())

		if !ok {
			panic("cannot get peer from context")
		}

		info := noise.InfoFromPeer(p)

		if info == nil {
			panic("cannot get info from peer")
		}

		id := info.Get(skademlia.KeyID)

		if id == nil {
			panic("cannot get id from peer")
		}

		fmt.Printf("message:%s %s %s\n", id, reflect.TypeOf(*txt).Name(), base64.StdEncoding.EncodeToString(txt.Bytes))
	}
}

const (
	C1 = 1
	C2 = 1
)

func log(args ...interface{}) {
	args[0] = fmt.Sprintf("log:%s", args[0])
	fmt.Println(args...)
}
func main() {
	flag.Parse()
	host := flag.Args()[0]
	port := flag.Args()[1]

	listener, err := net.Listen("tcp", ":"+port)
	if err != nil {
		panic(err)
	}

	log("Listening for peers on port:", listener.Addr().(*net.TCPAddr).Port)

	keys, err := skademlia.NewKeys(C1, C2)
	if err != nil {
		panic(err)
	}

	addr := net.JoinHostPort(host, strconv.Itoa(listener.Addr().(*net.TCPAddr).Port))

	client := skademlia.NewClient(addr, keys, skademlia.WithC1(C1), skademlia.WithC2(C2))
	client.SetCredentials(noise.NewCredentials(addr, handshake.NewECDH(), cipher.NewAEAD(), client.Protocol()))

	go func() {

		server := client.Listen()
		RegisterEllipticoinServer(server, &chatHandler{})

		if err := server.Serve(listener); err != nil {
			panic(err)
		}
	}()

	time.Sleep(100 * time.Millisecond)

	for _, addr := range flag.Args()[2:] {
		if _, err := client.Dial(addr); err != nil {
			fmt.Println(err)
		}
	}

	client.Bootstrap()
	fmt.Println("started")

	reader := bufio.NewReader(os.Stdin)

	for {
		line, _, err := reader.ReadLine()

		if err != nil {
			panic(err)
		}

		conns := client.ClosestPeers()

		for _, conn := range conns {
			chat := NewEllipticoinClient(conn)

			stream, err := chat.Stream(context.Background())
			if err != nil {
				continue
			}

			bytes, _ := base64.StdEncoding.DecodeString(strings.TrimSuffix(string(line), "\n"))
			if err := stream.Send(&Block{Bytes: bytes}); err != nil {
				continue
			}
		}

	}
}
