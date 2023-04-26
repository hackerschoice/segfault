all: Dockerfile
	docker build --network host --build-arg SF_PACKAGES="$(SF_PACKAGES)" --build-arg GITHUB_TOKEN="$(GITHUB_TOKEN)" -t sf-guest .

