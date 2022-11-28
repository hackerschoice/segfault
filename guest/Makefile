all: Dockerfile
	docker build --network host --build-arg SF_PACKAGES="$(SF_PACKAGES)" -t sf-guest .

