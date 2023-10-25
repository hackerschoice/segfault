package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"sync/atomic"
	"time"
)

type MetricLogger struct {
	LogQueue         chan *string // Queue of Metrics that is to be flushed
	LoggingActive    *atomic.Bool
	FlushInterval    time.Duration
	ElasticServerUrl string
	ElasticIndexName string
}

var MLogger = MetricLogger{}

func (metricLogger *MetricLogger) StartLogger(queueSize int, flushInterval int,
	elasticServerHost string, elasticIndexName string,
	elasticUsername string, elasticPassword string) {
	metricLogger.LogQueue = make(chan *string, queueSize)
	metricLogger.LoggingActive = &atomic.Bool{}
	metricLogger.LoggingActive.Store(true)
	metricLogger.FlushInterval = time.Second * time.Duration(flushInterval)
	metricLogger.ElasticIndexName = elasticIndexName
	metricLogger.ElasticServerUrl = fmt.Sprintf("https://%s:%s@%s", elasticUsername, elasticPassword, elasticServerHost)
	go metricLogger.periodicFlush()
}

func (metricLogger *MetricLogger) AddLogEntry(log *string) {
	if metricLogger.LoggingActive.Load() {

		var logEntry = make(map[string]string)
		logEntry["Time"] = time.Now().Format(time.RFC3339)

		// split by |
		sections := strings.Split(*log, "|")
		if len(sections) < 1 {
			return
		}

		// split by :
		for _, section := range sections {
			parts := strings.Split(section, ":")
			if len(parts) == 2 {
				logEntry[parts[0]] = parts[1]
			}
		}

		logBytes, jerr := json.Marshal(logEntry)
		logStr := string(logBytes)

		if jerr == nil {
			select {
			case metricLogger.LogQueue <- &logStr:
			default: // Channel full
			}
		}
	}
}

func (metricLogger *MetricLogger) periodicFlush() {
	for {
		time.Sleep(metricLogger.FlushInterval)
		metricLogger.FlushQueue()
	}
}

func (metricLogger *MetricLogger) FlushQueue() {
	logData := strings.Builder{}

outer:
	for { // Flush everything in the queue
		select {
		case LogEntry, ok := <-metricLogger.LogQueue:
			if !ok {
				break
			}

			logData.WriteString(`{ "index":{} }`)
			logData.WriteByte(10)
			logData.WriteString(*LogEntry)
			logData.WriteByte(10)

		default:
			break outer
		}
	}

	if logData.Len() > 0 {
		metricLogger.Insert(logData.String())
	}
}

func (metricLogger *MetricLogger) Insert(Data string) error {
	client := &http.Client{}
	req, err := http.NewRequest("POST", metricLogger.ElasticServerUrl+"/"+
		metricLogger.ElasticIndexName+"/_bulk", strings.NewReader(Data))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode == 201 {
		return nil
	}
	return errors.New("Insert Failed")
}
