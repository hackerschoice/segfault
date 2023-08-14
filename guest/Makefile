ifndef SF_NET
	SF_NET=host
endif

# expoirt SF_NET=container:sf-net
# export DOCKER_BUILDKIT=0
all: Dockerfile
	docker build --network $(SF_NET) --build-arg SF_PACKAGES="$(SF_PACKAGES)" --build-arg GITHUB_TOKEN="$(GITHUB_TOKEN)" -t sf-guest .

