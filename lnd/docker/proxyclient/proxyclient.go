package main

import (
	"fmt"
	"os"

	"github.com/btcsuite/btcd/wire"
)

func main() {
	path := os.Args[1]
	fmt.Println("Path: " + path)

	f, err := os.OpenFile(path, os.O_RDONLY, 0600)
	if err != nil {
		panic(err)
	}
	pver := wire.ProtocolVersion
	btcnet := wire.SimNet
	_, _, err = wire.ReadMessage(f, pver, btcnet)
	// msg, rawPayload, err := wire.ReadMessage(f, pver, btcnet)
	if err != nil {
		panic(err)
	}
}
