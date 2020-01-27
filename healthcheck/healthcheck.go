package main

import (
	"fmt"
	"os"

	"github.com/go-redis/redis"
)

func getRedisClient(hostname string, port string) *redis.Client {
	client := redis.NewClient(&redis.Options{
		Addr: fmt.Sprintf("%s:%s", hostname, port),
	})
	return client
}

func pingRedis(client *redis.Client) error {
	_, err := client.Ping().Result()
	return err
}

func main() {
	if len(os.Args) != 2 {
		fmt.Printf("Usage: %s <port>\n", os.Args[0])
		os.Exit(1)
	}

	client := getRedisClient("localhost", os.Args[1])
	defer client.Close()

	if err := pingRedis(client); err != nil {
		fmt.Printf("redis healthcheck error: %+v\n", err)
		os.Exit(1)
	}
	i := 3
	i += 1
	fmt.Printf("pong!")
}
