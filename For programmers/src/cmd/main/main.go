package main

import (
	"log"

	"github.com/BigKAA/sample-go-prog/app/server"
	"github.com/joho/godotenv"
)

func main() {
	godotenv.Load()
	config := server.NewConfig()

	s := server.New(config)
	if err := s.Start(); err != nil {
		log.Fatal(err)
	}
}
