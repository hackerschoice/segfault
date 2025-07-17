#! /bin/bash

# Docker sf-guest setup script (docker build)

CR="\e[1;31m" # red
CN="\e[0m"    # none

WARN()
{
	WARNS+=("$*")
}

# Fatal Error when any of the following commands fail
set -e

# ZSH setup
sed 's/#\(.*\)prompt_symbol=/\1prompt_symbol=/g' -i /etc/skel/.zshrc
sed 's/\(\s*PROMPT=.*\)n└─\(.*\)/\1n%{%G└%}%{%G─%}\2/g' -i /etc/skel/.zshrc
sed '/\^P toggle_oneline_prompt/d' -i /etc/skel/.zshrc
echo '[[ -e /etc/shellrc ]] && source /etc/shellrc' >>/etc/skel/.zshrc

echo '[[ -e /etc/shellrc ]] && source /etc/shellrc' >>/etc/skel/.bashrc
sed 's/\(\s*\)set mouse=/"\1set mouse=/g' -i /usr/share/vim/vim91/defaults.vim
[[ -e /etc/postgresql/15/main/postgresql.conf ]] && {
	sed 's/shared_buffers = [0-9]*\(.*\)/shared_buffers = 4\1/g' -i /etc/postgresql/15/main/postgresql.conf
	sed 's/#maintenance_work_mem = [0-9]*\(.*\)/maintenance_work_mem = 4\1/g' -i /etc/postgresql/15/main/postgresql.conf
	sed 's/#max_parallel_workers = [0-9]*\(.*\)/max_parallel_workers = 2\1/g' -i /etc/postgresql/15/main/postgresql.conf
	sed 's/#max_worker_processes = [0-9]*\(.*\)/max_worker_processes = 2\1/g' -i /etc/postgresql/15/main/postgresql.conf
}
rm -f /etc/skel/.bashrc.original
rm -f /usr/bin/kali-motd /etc/motd
chsh -s /bin/zsh
useradd  -s /bin/zsh user
ln -s openssh /usr/lib/ssh
sed 's/\/root/\/sec\/root/g' -i /etc/passwd
sed 's/\/home\//\/sec\/home\//g' -i /etc/passwd

# Docker depends on /root to exist or otherwise throws a:
# [process_linux.go:545: container init caused: mkdir /root: file exists: unknown]
# shellcheck disable=SC2114
rm -rf /root /home
mkdir -p /sec
cp -a /etc/skel /sec/root
ln -s /sec/root /root
cd . # Prevent 'getcwd() failed' after deleting my own directory
ln -s /sec/home /home
mkdir /run/mysqld

echo "NOT ENCRYPTED" >/sec/THIS-DIRECTORY-IS-NOT-ENCRYPTED--DO-NOT-USE.txt

# 2024 kali bug, shipped with cap_net_bind_service,cap_net_admin,cap_net_raw=eip, which will yield
# /usr/bin/nmap: Operation not permitted inside a container.
[ -e /usr/lib/nmap/nmap ] && setcap cap_net_bind_service,cap_net_raw=eip /usr/lib/nmap/nmap

# Need to set correct permission which may have gotten skewed when building
# docker inside vmbox from shared host drive. On VMBOX share all
# source files and directories are set to "rwxrwx--- root:vobxsf" :/
fixr()
{
	local dir
	dir=$1
	[[ ! -d "$dir" ]] && return

	find "$dir" -type f -exec chmod 644 {} \;
	find "$dir" -type d -exec chmod 755 {} \;
}
ln -sf /sec/usr/etc/rc.local /etc/rc.local
chown root:root /etc /etc/profile.d /etc/profile.d/segfault.sh
chmod 755 /usr /usr/bin /usr/sbin /usr/share /etc /etc/profile.d
chmod 755 /usr/bin/mosh-server-hook /usr/bin/xpra-hook /usr/bin/brave-browser-stable-hook /usr/share/code/code-hook /usr/share/code/bin/code-hook /usr/bin/xterm-dark /usr/sbin/halt /usr/bin/username-anarchy
chmod 644 /etc/profile.d/segfault.sh
chmod 644 /etc/shellrc /etc/zsh_command_not_found /etc/zsh_profile
fixr /usr/share/www
fixr /usr/share/source-highlight
ln -s batcat /usr/bin/bat
[[ ! -e /usr/bin/cme ]] && ln -s crackmapexec /usr/bin/cme
ln -s /sf/bin/sf-motd.sh /usr/bin/motd
ln -s /sf/bin/sf-motd.sh /usr/bin/info
rm -f /usr/sbin/shutdown /usr/sbin/reboot
ln -s /usr/sbin/halt /usr/sbin/shutdown
ln -s /usr/sbin/halt /usr/sbin/reboot
[[ ! -e /usr/bin/vscode ]] && ln -sf /usr/bin/code /usr/bin/vscode
# No idea why /etc/firefox-esr does not work...
if [[ -e /usr/lib/firefox/defaults/pref/channel-prefs.js ]]; then
	echo 'pref("network.dns.blockDotOnion", false);
pref("browser.tabs.inTitlebar", 1);
pref("browser.shell.checkDefaultBrowser", false);' >>/usr/lib/firefox/defaults/pref/channel-prefs.js
else
	[[ -e /usr/bin/firefox ]] && WARN "Firefox config could not be updated."
fi
ln -s /usr/games/lolcat /usr/bin/lolcat

[[ -f /usr/share/wordlists/rockyou.txt.gz ]] && gunzip /usr/share/wordlists/rockyou.txt.gz
cd /var/log
rm -f dpkg.log alternatives.log fontconfig.log apt/*
set +e

# Non-Fatal. WARN but continue if any of the following commands fail
sed 's/^TorAddress.*/TorAddress 172.20.0.111/' -i /etc/tor/torsocks.conf || WARN "Failed /etc/tor/torsocks.conf"
sed 's/^worker_processes.*/worker_processes 2;/' -i /etc/nginx/nginx.conf || WARN "Failed /etc/nginx/nginx.conf"
sed 's/^Exec.*/Exec=xterm-dark/' -i /usr/share/applications/debian-xterm.desktop

# Move "$1" to "$1".orig and link "$1" -> "$1"-hook
mk_hook()
{
	local fn
	fn="${1}/${2}"
	[[ ! -e "$fn" ]] && return
	( cd "${1}"
	mv "$fn" "${fn}.orig"
	ln -s "${fn}-hook" "$fn" )
}
mk_hook /usr/bin        mosh-server
mk_hook /usr/bin        xpra
mk_hook /usr/bin        brave-browser-stable
mk_hook /usr/bin        chromium
mk_hook /usr/share/code/bin code
mk_hook /usr/share/code code
[[ -f /usr/share/code/bin/code.orig ]] && sed 's/PATH\/code\"/PATH\/code.orig\"/' -i /usr/share/code/bin/code.orig

# Apache needs to enable modules
command  -v a2enmod >/dev/null && a2enmod php8.4

# link SRC -> DST
# link chaos chaos-client
# link() {
# 	local srcp="${1:?}"
# 	local dstp="${2:?}"
# 	local dbin
# 	local dir
# 	dbin="$(command -v "${dstp}")" || return
# 	[[ ! -x "${dbin}" ]] && return
# 	dir="$(dirname "${dst}")" || return
# 	ln -s "${dstp}" "$(dirname "${dbin}")/${srcp}"
# }
# link chaos chaos-client

# git diff delta and other options
[[ -f /usr/bin/delta ]] && cat /gitconfig-stub >>/etc/gitconfig 

# 2024-08-02 bug when 'apt upgrade' starts 'telinit' and it consumes 100% cpu power FOREVER. 
[[ -e /usr/sbin/telinit ]] && rm -f /usr/sbin/telinit

# Made NodeJS crappy code us a better malloc allocation that releases
# memory to the kernel more aggressively than glibc.
[ -f /usr/lib/x86_64-linux-gnu/libjemalloc.so.2 ] && [ -f /usr/bin/node ] && command -v patchelf && patchelf --add-needed /usr/lib/x86_64-linux-gnu/libjemalloc.so.2 /usr/bin/node

# Output warnings and wait (if there are any)
[[ ${#WARNS[@]} -gt 0 ]] && {
	while [[ $i -lt ${#WARNS[@]} ]]; do
		((i++))
		echo -e "[${CR}WARN #$i${CN}] ${WARNS[$((i-1))]}"
	done
	echo "Continuing in 5 seconds..."
	sleep 5
}

# Fix curl-impersonate to use exec instead of forking and waiting...
(cd /usr/bin
[ -e curl_edge101 ] && for  x in curl_*; do sed -i -E 's|^"\$dir(.*)|exec "\$dir(\1)|g' "$x"; done)

ln -s xfce-applications.menu /etc/xdg/menus/applications.menu

exit 0
