ifndef SF_NET
	SF_NET=host
endif

# Zero keeps strict failure handling; positive values abort at that count.
SF_MAX_PACKAGE_FAILURES ?= 100
SF_GUEST_IMAGE ?= sf-guest

.PHONY: all report clean
all: Dockerfile
	@set --; if [ -n "$$GITHUB_TOKEN" ]; then set -- --secret id=github_token,env=GITHUB_TOKEN; fi; \
	DOCKER_BUILDKIT=1 docker build --pull --network "$(SF_NET)" "$$@" --build-arg SF_PACKAGES="$(SF_PACKAGES)" --build-arg SF_MAX_PACKAGE_FAILURES="$(SF_MAX_PACKAGE_FAILURES)" -t "$(SF_GUEST_IMAGE)" .
	@$(MAKE) --no-print-directory report

report:
	@docker run --rm --network none --read-only -e SF_MAX_PACKAGE_FAILURES="$(SF_MAX_PACKAGE_FAILURES)" --entrypoint /sf/bin/pkg-install.sh "$(SF_GUEST_IMAGE)" --report

clean:
	docker image rm "$(SF_GUEST_IMAGE)"
