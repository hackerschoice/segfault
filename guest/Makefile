ifndef SF_NET
	SF_NET=host
endif

# DOCKER_BUILDKIT=0 SF_NET=container:sf-mullvad make

# export SF_NET=container:vpn
# export SF_NET=container:sf-mullvad
# export DOCKER_BUILDKIT=0
all: Dockerfile
	docker build --network $(SF_NET) --build-arg SF_PACKAGES="$(SF_PACKAGES)" --build-arg GITHUB_TOKEN="$(GITHUB_TOKEN)" -t sf-guest .

clean:
	docker image rm sf-guest
