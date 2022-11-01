VERSION := $(shell git rev-parse --short HEAD)
BUILDTIME := $(shell date -u '+%Y-%m-%dT%H:%M:%SZ')

GOLDFLAGS += -s -w
GOLDFLAGS += -X main.Version=$(VERSION)
GOLDFLAGS += -X main.Buildtime=$(BUILDTIME)
GOFLAGS = -ldflags "$(GOLDFLAGS)"

all:
	docker build -t sf-containerguard .

build: pre
	GOOS=linux GOARCH=amd64 go build $(GOFLAGS)

build-arm: pre
	GOOS=linux GOARCH=arm go build -o cg-arm

pre:
	go mod tidy

docker: all
	docker run -it --rm sf-containerguard

release: build
	sha256sum cg | tee cg.sum
	tar czvf cg.tgz cg cg.sum
	rm -f cg cg.sum
	git add cg.tgz
	git commit -m "cg: release"
	git push
