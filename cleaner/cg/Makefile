all:
	docker build -t sf-containerguard .

build: pre
	GOOS=linux GOARCH=amd64 go build

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
