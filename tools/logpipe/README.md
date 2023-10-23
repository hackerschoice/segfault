### LogPipe
Accept logs via cmdline and ship them to elasticsearch

### Building
-   `go build -o bin/logpipe`
or via docker
-   `docker build -t sf-logpipe .`
-   `docker-compose up -d`

### Adding a log entry
-   Start the program - `./bin/logpipe` (ignore if using docker)
-   Then run `echo "Myattribute:MyValue|Myattribute2:MyValue2|"  | nc -U ./logPipe.sock`
or
-   `echo "Myattribute:MyValue|Myattribute2:MyValue2|"  | uniz-socket-client`

Notes:
-   Log format  is "attr:val|", each attribute-value pair must be terminated with a pipe(|)
-   Timestamp is automatically added to log entries
-   Elasticsearch credentials must be configured in `config.yaml`
-   Program/Container must be restarted after config changes