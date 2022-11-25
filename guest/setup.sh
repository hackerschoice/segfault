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
sed 's/\(\s*\)set mouse=/"\1set mouse=/g' -i /usr/share/vim/vim90/defaults.vim
rm -f /etc/skel/.bashrc.original
rm -f /usr/bin/kali-motd /etc/motd
chsh -s /bin/zsh
useradd  -s /bin/zsh user
ln -s openssh /usr/lib/ssh
sed 's/\/root/\/sec\/root/g' -i /etc/passwd
sed 's/\/home\//\/sec\/home\//g' -i /etc/passwd

# Docker depends on /root to exist or otherwise throws a:
# [process_linux.go:545: container init caused: mkdir /root: file exists: unknown]
rm -rf /root /home
mkdir -p /sec/root
ln -s /sec/root /root
ln -s /sec/home /home
cp -a /etc/skel /sec/root

echo "NOT ENCRYPTED" >/sec/THIS-DIRECTORY-IS-NOT-ENCRYPTED--DO-NOT-USE.txt

# Need to set correct permission which may have gotten skewed when building
# docker inside vmbox from shared host drive. On VMBOX share all
# source files are set to "rwxrwx--- root:vobxsf" :/
ln -sf /sec/usr/etc/rc.local /etc/rc.local
chown root:root /etc /etc/profile.d /etc/profile.d/segfault.sh
chmod 755 /usr /etc /etc/profile.d
chmod 644 /etc/profile.d/segfault.sh
chmod 644 /etc/shellrc /etc/zsh_command_not_found /etc/zsh_profile
find /usr/share/www -type f -exec chmod 644 {} \;
find /usr/share/www -type d -exec chmod 755 {} \;
ln -s batcat /usr/bin/bat
ln -s /sf/bin/sf-motd.sh /usr/bin/motd
ln -s /sf/bin/sf-motd.sh /usr/bin/help
set +e

# Non-Fatal. WARN but continue if any of the following commands fail
sed 's/^TorAddress.*/ToorAddress 172.20.0.111/' -i /etc/tor/torsocks.conf || WARN "Failed /etc/tor/torsocks.conf"
[[ -f /usr/bin/mosh-server ]] && mv /usr/bin/mosh-server /usr/bin/mosh-server.orig
[[ -f /usr/bin/mosh-server.sh ]] && { mv /usr/bin/mosh-server.sh /usr/bin/mosh-server; chmod 755 /usr/bin/mosh-server; }

# Output warnings and wait (if there are any)
[[ ${#WARNS[@]} -gt 0 ]] && {
	echo -e "Blah"
	while [[ $i -lt ${#WARNS[@]} ]]; do
		((i++))
		echo -e "${CR}[WARN #$i]${CN} ${WARNS[$((i-1))]}"
	done
	echo "Continuing in 5 seconds..."
	sleep 5
}

exit 0
