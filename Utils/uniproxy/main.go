package main

import (
	"fmt"
	"os"

	"github.com/bigkaa/uniproxy/apiserver"
)

func main() {
	config, err := apiserver.NewConfig()
	if err != nil {
		fmt.Printf("Error %v:", err)
		os.Exit(1)
	}
	config.Start()
}
