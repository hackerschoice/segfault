VER := 0.5.7rc1

all:
	make -C router
	make -C tools/cg
	make -C tools/logpipe
	make -C master
	make -C host
	make -C tor
	make -C encfsd
	make -C gsnc
	make -C guest
	docker pull redis
	docker pull nginx
	docker pull hackerschoice/cryptostorm
	docker pull 4km3/dnsmasq:2.85-r2
	docker pull crazymax/cloudflared

FILES_GUEST += "segfault-$(VER)/guest/setup.sh"
FILES_GUEST += "segfault-$(VER)/guest/gitconfig-stub"
FILES_GUEST += "segfault-$(VER)/guest/Dockerfile"
FILES_GUEST += "segfault-$(VER)/guest/Makefile"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/sbin/halt"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/bin/mosh-server-hook"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/bin/xpra-hook"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/bin/brave-browser-stable-hook"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/bin/chromium-hook"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/share/code/code-hook"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/share/code/bin/code-hook"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/bin/username-anarchy"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/bin/xterm-dark"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/bin/xterm-dark-xpra"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/profile.d/segfault.sh"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/shellrc"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/skel/.config/htop/htoprc"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/zsh_profile"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/zsh_command_not_found"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/zsh/zshenv"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/proxychains.conf"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/etc/xdg/nvim/sysinit.vim"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/etc/redsocks-1040.conf"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/sf-motd.sh"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/funcs.sh"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/funcs_extra.sh"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/crt"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/addfileextension"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/destruct"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/funcs_motd-xpra"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/sf-setup.sh"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/startxvnc"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/startxweb"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/startfb"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/geoip"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/geoiphn"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/gssec"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/gsexec"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/gsexecio"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/d"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/str2mnemonic"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/thcssh"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/transfer"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/asn"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/sshj"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/shred"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/rshell"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/funcs_ip.sh"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/funcs_rport.sh"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/io"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/io2"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/dns"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/rdns"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/ptr"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/resolv"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/find_subdomains"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/exfil"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/pkg-install.sh"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/sf/bin/proxy"
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
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/share/applications/metasploit.desktop"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/share/applications/burpsuite.desktop"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/share/applications/thc-tips-and-tricks.desktop"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/share/icons/metasploit.svg"
FILES_GUEST += "segfault-$(VER)/guest/fs-root/usr/share/icons/thc-logo.jpg"
FILES_GUEST += "segfault-$(VER)/guest/fs-root-amd64/usr/bin/xmap"

FILES_MASTER += "segfault-$(VER)/master/Dockerfile"
FILES_MASTER += "segfault-$(VER)/master/Makefile"
FILES_MASTER += "segfault-$(VER)/master/init-master.sh"
FILES_MASTER += "segfault-$(VER)/master/dict.txt"
FILES_MASTER += "segfault-$(VER)/master/ready-lg.sh"
FILES_MASTER += "segfault-$(VER)/master/cgi-bin/rpc"

FILES_HOST += "segfault-$(VER)/host/Dockerfile"
FILES_HOST += "segfault-$(VER)/host/Makefile"
FILES_HOST += "segfault-$(VER)/host/docker-exec-sigproxy.c"
FILES_HOST += "segfault-$(VER)/host/unix-socket-client.c"
FILES_HOST += "segfault-$(VER)/host/mk_sshd.sh"
FILES_HOST += "segfault-$(VER)/host/sf-sshd.patch"
FILES_HOST += "segfault-$(VER)/host/setup.sh"
FILES_HOST += "segfault-$(VER)/host/fs-root/bin/segfaultsh"
FILES_HOST += "segfault-$(VER)/host/fs-root/bin/webshellsh"
FILES_HOST += "segfault-$(VER)/host/fs-root/bin/asksecsh"
FILES_HOST += "segfault-$(VER)/host/fs-root/bin/sf_trace-DISABLED"
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
FILES_PROVISION += "segfault-$(VER)/provision/system/sf-guest.slice"
FILES_PROVISION += "segfault-$(VER)/provision/env.example"
FILES_PROVISION += "segfault-$(VER)/provision/update.sh"

FILES_ENCFSD += "segfault-$(VER)/encfsd/Makefile"
FILES_ENCFSD += "segfault-$(VER)/encfsd/Dockerfile"
FILES_ENCFSD += "segfault-$(VER)/encfsd/destructor.sh"
FILES_ENCFSD += "segfault-$(VER)/encfsd/funcs_destructor.sh"
FILES_ENCFSD += "segfault-$(VER)/encfsd/encfsd.sh"
FILES_ENCFSD += "segfault-$(VER)/encfsd/portd.sh"

FILES_ROUTER += "segfault-$(VER)/router/Makefile"
FILES_ROUTER += "segfault-$(VER)/router/Dockerfile"
FILES_ROUTER += "segfault-$(VER)/router/fix-network.sh"
FILES_ROUTER += "segfault-$(VER)/router/init.sh"
FILES_ROUTER += "segfault-$(VER)/router/init-wg.sh"
FILES_ROUTER += "segfault-$(VER)/router/init-novpn.sh"
FILES_ROUTER += "segfault-$(VER)/router/user-limit.sh"

FILES_GSNC += "segfault-$(VER)/gsnc/Makefile"
FILES_GSNC += "segfault-$(VER)/gsnc/Dockerfile"
FILES_GSNC += "segfault-$(VER)/gsnc/sf-gsnc.sh"

FILES_CONFIG += "segfault-$(VER)/config/etc/nginx/nginx.conf"
FILES_CONFIG += "segfault-$(VER)/config/etc/nginx/nginx-rpc.conf"
FILES_CONFIG += "segfault-$(VER)/config/etc/sf/sf.conf"
FILES_CONFIG += "segfault-$(VER)/config/etc/sf/timers.conf"
FILES_CONFIG += "segfault-$(VER)/config/etc/redis/redis.conf"
FILES_CONFIG += "segfault-$(VER)/config/etc/sf/WARNING---SHARED-BETWEEN-ALL-SERVERS---README.txt"
FILES_CONFIG += "segfault-$(VER)/config/etc/resolv.conf"
FILES_CONFIG += "segfault-$(VER)/config/etc/loginmsg-new.sh-example"
FILES_CONFIG += "segfault-$(VER)/config/etc/loginmsg-all.sh-example"
FILES_CONFIG += "segfault-$(VER)/config/etc/logoutmsg-all.sh-example"
FILES_CONFIG += "segfault-$(VER)/config/etc/logpipe/config.yaml"
FILES_CONFIG += "segfault-$(VER)/config/etc/ssh/banner_example"

FILES_ROOT += "segfault-$(VER)/Makefile"
FILES_ROOT += "segfault-$(VER)/ChangeLog"
FILES_ROOT += "segfault-$(VER)/docker-compose.yml"
FILES_ROOT += "segfault-$(VER)/sfbin/wait_semaphore.sh"
FILES_ROOT += "segfault-$(VER)/sfbin/vpn_wg2status.sh"
FILES_ROOT += "segfault-$(VER)/sfbin/rportfw.sh"
FILES_ROOT += "segfault-$(VER)/sfbin/funcs.sh"
FILES_ROOT += "segfault-$(VER)/sfbin/funcs_redis.sh"
FILES_ROOT += "segfault-$(VER)/sfbin/funcs_admin.sh"
FILES_ROOT += "segfault-$(VER)/sfbin/funcs_net.sh"
FILES_ROOT += "segfault-$(VER)/sfbin/funcs_ovpn.sh"
FILES_ROOT += "segfault-$(VER)/sfbin/ovpn_up.sh"
FILES_ROOT += "segfault-$(VER)/sfbin/sf"
FILES_ROOT += "segfault-$(VER)/sfbin/banhammer.sh"

FILES_CLEANER += "segfault-$(VER)/tools/cg/Dockerfile"
FILES_CLEANER += "segfault-$(VER)/tools/cg/go.mod"
FILES_CLEANER += "segfault-$(VER)/tools/cg/go.sum"
FILES_CLEANER += "segfault-$(VER)/tools/cg/main.go"
FILES_CLEANER += "segfault-$(VER)/tools/cg/Makefile"
FILES_CLEANER += "segfault-$(VER)/tools/cg/sysinfo_linux.go"
FILES_CLEANER += "segfault-$(VER)/tools/logpipe/Makefile"
FILES_CLEANER += "segfault-$(VER)/tools/logpipe/Dockerfile"
FILES_CLEANER += "segfault-$(VER)/tools/logpipe/go.sum"
FILES_CLEANER += "segfault-$(VER)/tools/logpipe/go.mod"
FILES_CLEANER += "segfault-$(VER)/tools/logpipe/main.go"
FILES_CLEANER += "segfault-$(VER)/tools/logpipe/metrics.go"

FILES_CONTRIB += "segfault-$(VER)/contrib/sfwg"
FILES_CONTRIB += "segfault-$(VER)/contrib/cronjob"

FILES += $(FILES_CLEANER) $(FILES_MASTER) $(FILES_ROOT) $(FILES_GSNC) $(FILES_CONFIG) $(FILES_ROUTER) $(FILES_TOR) $(FILES_ENCFSD) $(FILES_GUEST) $(FILES_HOST) $(FILES_PROVISION) $(FILES_CONTRIB)
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
