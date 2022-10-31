VERSION := $(shell git rev-parse --short HEAD)
BUILDTIME := $(shell date -u '+%Y-%m-%dT%H:%M:%SZ')

GOLDFLAGS += -s -w
GOLDFLAGS += -X main.Version=$(VERSION)
GOLDFLAGS += -X main.Buildtime=$(BUILDTIME)
GOFLAGS = -ldflags "$(GOLDFLAGS)"

build: pre
	GOOS=linux GOARCH=amd64 go build $(GOFLAGS)

upload:
	scp -P64222 cg root@bh.segfault.net:/usr/bin/cg.new
	ssh -p64222 root@bh.segfault.net mv /usr/bin/cg.new /usr/bin/cg

build-arm: pre
	GOOS=linux GOARCH=arm go build -o cg-arm

pre:
	go mod tidy

docker:
	docker built -t cg .
	docker run -it --rm cg

release: build
	sha256sum cg | tee cg.sum
	tar czvf cg.tgz cg cg.sum
	rm -f cg cg.sum
	git add cg.tgz
	git commit -m "cg: release"
	git push
