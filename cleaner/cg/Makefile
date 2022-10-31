build: pre
	GOOS=linux GOARCH=amd64 go build

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
