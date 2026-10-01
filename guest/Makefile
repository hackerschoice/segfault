ifndef SF_NET
	SF_NET=host
endif

# DOCKER_BUILDKIT=0 SF_NET=container:sf-mullvad make
# Kali' mirror firewall multiple connections (like berkely), so we must disable BUILDKIT
# so that docker can build this.

# export SF_NET=container:vpn
# export SF_NET=container:sf-mullvad
# export DOCKER_BUILDKIT=0
# Zero keeps strict failure handling; positive values abort at that count.
SF_MAX_PACKAGE_FAILURES ?= 100
SF_GUEST_IMAGE ?= sf-guest

all: Dockerfile
	DOCKER_BUILDKIT=0 docker build --pull --network $(SF_NET) --build-arg SF_PACKAGES="$(SF_PACKAGES)" --build-arg GITHUB_TOKEN="$(GITHUB_TOKEN)" --build-arg SF_MAX_PACKAGE_FAILURES="$(SF_MAX_PACKAGE_FAILURES)" -t "$(SF_GUEST_IMAGE)" .

clean:
	docker image rm "$(SF_GUEST_IMAGE)"
