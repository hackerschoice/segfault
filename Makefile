VER := 0.1-beta8c

all:
	make -C guest
	make -C host
	make -C tor
	make -C encfs
	make -C router

FILES_GUEST += "segfault-$(VER)/guest/setup.sh"
FILES_GUEST += "segfault-$(VER)/guest/Dockerfile"
FILES_GUEST += "segfault-$(VER)/guest/Makefile"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/sbin/halt"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/profile.d/segfault.sh"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/shellrc"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/sf-motd.sh"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/sf-destructor.sh"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/sf-setup.sh"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/rc.local-example"

FILES_HOST += "segfault-$(VER)/host/setup.sh"
FILES_HOST += "segfault-$(VER)/host/Dockerfile"
FILES_HOST += "segfault-$(VER)/host/Makefile"
FILES_HOST += "segfault-$(VER)/host/fs-root/bin/segfaultsh"
FILES_HOST += "segfault-$(VER)/host/fs-root/bin/docker_sshd.sh"
FILES_HOST += "segfault-$(VER)/host/fs-root/etc/ssh/sshd_config"
FILES_HOST += "segfault-$(VER)/host/fs-root/etc/english.txt"

FILES_TOR += "segfault-$(VER)/tor/Dockerfile"
FILES_TOR += "segfault-$(VER)/tor/Makefile"
FILES_TOR += "segfault-$(VER)/tor/fs-root/sf-tor.sh"

FILES_PROVISION += "segfault-$(VER)/provision/init-ubuntu.sh"
FILES_PROVISION += "segfault-$(VER)/provision/system/funcs"
FILES_PROVISION += "segfault-$(VER)/provision/env.example"

FILES_ENCFS += "segfault-$(VER)/encfs/Makefile"
FILES_ENCFS += "segfault-$(VER)/encfs/Dockerfile"
FILES_ENCFS += "segfault-$(VER)/encfs/mount.sh"

FILES_ROUTER += "segfault-$(VER)/router/Makefile"
FILES_ROUTER += "segfault-$(VER)/router/Dockerfile"
FILES_ROUTER += "segfault-$(VER)/router/fix-network.sh"
FILES_ROUTER += "segfault-$(VER)/router/init.sh"
FILES_ROUTER += "segfault-$(VER)/router/tc.sh"
FILES_ROUTER += "segfault-$(VER)/sfbin/vpn_wg2status.sh"

FILES_CONFIG += "segfault-$(VER)/config/etc/nginx/nginx.conf"
FILES_CONFIG += "segfault-$(VER)/config/etc/tc/limits.conf"

FILES_ROOT += "segfault-$(VER)/Makefile"
FILES_ROOT += "segfault-$(VER)/docker-compose.yml"

FILES += $(FILES_ROOT) $(FILES_CONFIG) $(FILES_ROUTER) $(FILES_TOR) $(FILES_ENCFS) $(FILES_GUEST) $(FILES_HOST) $(FILES_PROVISION)
TARX = $(shell command -v gtar 2>/dev/null)
ifndef TARX
	TARX := tar
endif

install:
	@ echo "Try provision/init-ubuntu.sh"

dist:
	rm -f segfault-$(VER) 2>/dev/null
	ln -sf . segfault-$(VER)
	$(TARX) cfz segfault-$(VER).tar.gz --owner=0 --group=0  $(FILES)
	rm -f segfault-$(VER)
	ls -al segfault-$(VER).tar.gz
