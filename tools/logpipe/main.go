package main

import (
	"fmt"
	"log"
	"net"
	"os"

	"gopkg.in/yaml.v2"
)

type LogPipe struct {
	MetricLoggerQueueSize int    `yaml:"metric_logger_queue_size"`
	MetricFlushInterval   int    `yaml:"metric_flush_interval"`
	ElasticServerHost     string `yaml:"elastic_server_host"`
	ElasticIndexName      string `yaml:"elastic_index_name"`
	ElasticUsername       string `yaml:"elastic_username"`
	ElasticPassword       string `yaml:"elastic_password"`
}

func main() {
	lp := LogPipe{}

	fbytes, ferr := os.ReadFile("config.yaml")
	if ferr == nil {
		err := yaml.Unmarshal(fbytes, &lp)
		if err != nil {
			log.Println("Failed Unmarshal data", err)
		}

		MLogger.StartLogger(lp.MetricLoggerQueueSize, 1,
			lp.ElasticServerHost, lp.ElasticIndexName,
			lp.ElasticUsername, lp.ElasticPassword)
		log.Println("Listening on socket logPipe.sock")
		listenOnSocket("./sock/logPipe.sock")
	} else {
		log.Println("Could not read config.yaml")
	}
}

func listenOnSocket(socketFile string) {
	os.Remove(socketFile)

	listener, err := net.Listen("unix", socketFile)
	if err != nil {
		fmt.Println("Error creating listener:", err)
		return
	}

	for {
		conn, err := listener.Accept()
		if err != nil {
			fmt.Println("Error accepting connection:", err)
			continue
		}

		go handleConnection(conn)
	}
}

func handleConnection(conn net.Conn) {
	defer conn.Close()

	buf := make([]byte, 2048)
	_, err := conn.Read(buf)
	if err != nil {
		log.Println("Error reading from connection:", err)
		return
	}

	logStr := string(buf)
	MLogger.AddLogEntry(&logStr)
}
