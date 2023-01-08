VER := 0.3.9a2

all:
	make -C cleaner/cg
	make -C host
	make -C tor
	make -C encfsd
	make -C router
	make -C gsnc
	make -C guest
	docker pull redis
	docker pull nginx
	docker pull hackerschoice/cryptostorm
	docker pull 4km3/dnsmasq:2.85-r2
	docker pull crazymax/cloudflared

FILES_GUEST += "segfault-$(VER)/guest/setup.sh"
FILES_GUEST += "segfault-$(VER)/guest/Dockerfile"
FILES_GUEST += "segfault-$(VER)/guest/Makefile"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/sbin/halt"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/bin/mosh-server.sh"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/profile.d/segfault.sh"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/shellrc"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/zsh_profile"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/zsh_command_not_found"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/proxychains.conf"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/sf-motd.sh"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/sf-setup.sh"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/pkg-install.sh"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/rc.local-example"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/vim/vimrc.local"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/apt/apt.conf.d/01norecommend"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/cheat/conf.yml"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/ld.so.conf.d/sf.conf"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/share/source-highlight/src-hilite-lesspipe.sh"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/share/www/pelicanconf.py"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/share/www/tasks.py"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/share/www/Makefile"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/share/www/content/Articles/hello.md"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/share/www/content/Articles/world.md"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/share/www/content/pages/mydw.md"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/share/www/content/pages/about.md"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/share/www/content/images"

FILES_HOST += "segfault-$(VER)/host/Dockerfile"
FILES_HOST += "segfault-$(VER)/host/Makefile"
FILES_HOST += "segfault-$(VER)/host/docker-exec-sigproxy.c"
FILES_HOST += "segfault-$(VER)/host/fs-root/bin/segfaultsh"
FILES_HOST += "segfault-$(VER)/host/fs-root/bin/docker_sshd.sh"
FILES_HOST += "segfault-$(VER)/host/fs-root/bin/mmdbinspect"
FILES_HOST += "segfault-$(VER)/host/fs-root/etc/ssh/sshd_config"
FILES_HOST += "segfault-$(VER)/host/fs-root/etc/english.txt"

FILES_TOR += "segfault-$(VER)/tor/Dockerfile"
FILES_TOR += "segfault-$(VER)/tor/Makefile"
FILES_TOR += "segfault-$(VER)/tor/fs-root/sf-tor.sh"

FILES_PROVISION += "segfault-$(VER)/provision/funcs_aws.sh"
FILES_PROVISION += "segfault-$(VER)/provision/funcs_al2.sh"
FILES_PROVISION += "segfault-$(VER)/provision/funcs_ubuntu.sh"
FILES_PROVISION += "segfault-$(VER)/provision/init-linux.sh"
FILES_PROVISION += "segfault-$(VER)/provision/system/funcs"
FILES_PROVISION += "segfault-$(VER)/provision/system/sf.slice"
FILES_PROVISION += "segfault-$(VER)/provision/system/sf_guest.slice"
FILES_PROVISION += "segfault-$(VER)/provision/system/daemon.json"
FILES_PROVISION += "segfault-$(VER)/provision/env.example"
FILES_PROVISION += "segfault-$(VER)/provision/update.sh"

FILES_ENCFSD += "segfault-$(VER)/encfsd/Makefile"
FILES_ENCFSD += "segfault-$(VER)/encfsd/Dockerfile"
FILES_ENCFSD += "segfault-$(VER)/encfsd/destructor.sh"
FILES_ENCFSD += "segfault-$(VER)/encfsd/encfsd.sh"
FILES_ENCFSD += "segfault-$(VER)/encfsd/portd.sh"

FILES_ROUTER += "segfault-$(VER)/router/Makefile"
FILES_ROUTER += "segfault-$(VER)/router/Dockerfile"
FILES_ROUTER += "segfault-$(VER)/router/fix-network.sh"
FILES_ROUTER += "segfault-$(VER)/router/init.sh"
FILES_ROUTER += "segfault-$(VER)/router/tc.sh"

FILES_GSNC += "segfault-$(VER)/gsnc/Makefile"
FILES_GSNC += "segfault-$(VER)/gsnc/Dockerfile"
FILES_GSNC += "segfault-$(VER)/gsnc/sf-gsnc.sh"

FILES_CONFIG += "segfault-$(VER)/config/etc/nginx/nginx.conf"
FILES_CONFIG += "segfault-$(VER)/config/etc/sf/sf.conf"
FILES_CONFIG += "segfault-$(VER)/config/etc/redis/redis.conf"
FILES_CONFIG += "segfault-$(VER)/config/etc/sf/WARNING---SHARED-BETWEEN-ALL-SERVERS---README.txt"
FILES_CONFIG += "segfault-$(VER)/config/etc/hosts"
FILES_CONFIG += "segfault-$(VER)/config/etc/resolv.conf"

FILES_ROOT += "segfault-$(VER)/Makefile"
FILES_ROOT += "segfault-$(VER)/ChangeLog"
FILES_ROOT += "segfault-$(VER)/docker-compose.yml"
FILES_ROOT += "segfault-$(VER)/sfbin/wait_semaphore.sh"
FILES_ROOT += "segfault-$(VER)/sfbin/vpn_wg2status.sh"
FILES_ROOT += "segfault-$(VER)/sfbin/rportfw.sh"
FILES_ROOT += "segfault-$(VER)/sfbin/funcs.sh"
FILES_ROOT += "segfault-$(VER)/sfbin/funcs_redis.sh"
FILES_ROOT += "segfault-$(VER)/sfbin/funcs_admin.sh"
FILES_ROOT += "segfault-$(VER)/sfbin/sf"

FILES_CLEANER += "segfault-$(VER)/cleaner/cg/Dockerfile"
FILES_CLEANER += "segfault-$(VER)/cleaner/cg/go.mod"
FILES_CLEANER += "segfault-$(VER)/cleaner/cg/go.sum"
FILES_CLEANER += "segfault-$(VER)/cleaner/cg/main.go"
FILES_CLEANER += "segfault-$(VER)/cleaner/cg/Makefile"
FILES_CLEANER += "segfault-$(VER)/cleaner/cg/sysinfo_linux.go"

FILES += $(FILES_CLEANER) $(FILES_ROOT) $(FILES_GSNC) $(FILES_CONFIG) $(FILES_ROUTER) $(FILES_TOR) $(FILES_ENCFSD) $(FILES_GUEST) $(FILES_HOST) $(FILES_PROVISION)
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
