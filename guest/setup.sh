#! /bin/bash

# Docker sf-guest setup script (docker build)

sed -i 's/#\(.*\)prompt_symbol=/\1prompt_symbol=/g' /etc/skel/.zshrc && \
sed -i 's/\(\s*PROMPT=.*\)n└─\(.*\)/\1n%{%G└%}%{%G─%}\2/g' /etc/skel/.zshrc && \
echo '[[ -e /etc/shellrc ]] && source /etc/shellrc' >>/etc/skel/.zshrc && \
echo '[[ -e /etc/shellrc ]] && source /etc/shellrc' >>/etc/skel/.bashrc && \
sed -i 's/ set mouse=a/"set mouse=a/g' /usr/share/vim/vim82/defaults.vim && \
rm -f /etc/skel/.bashrc.original && \
rm -f /usr/bin/kali-motd && \
chsh -s /bin/zsh
useradd  -s /bin/zsh user && \
sed -i 's/\/root/\/sec\/root/g' /etc/passwd && \
sed -i 's/\/home\//\/sec\/home\//g' /etc/passwd && \
mkdir -p /sec && \
echo "NOT ENCRYPTED" >/sec/THIS-DIRECTORY-IS-NOT-ENCRYPTED--DO-NOT-USE.txt && \
# Docker depends on /root to exist or otherwise throws a:
# [process_linux.go:545: container init caused: mkdir /root: file exists: unknown]
rm -rf /root && \
cp -a /etc/skel /sec/root && \
mkdir /root && \
#
# Need to set correct permission which may have gotten skewed when building
# docker inside vmbox from shared host drive. On VMBOX share all
# source files are set to "rwxrwx--- root:vobxsf" :/
ln -sf /sec/usr/etc/rc.local /etc/rc.local && \
chown root:root /etc /etc/profile.d /etc/profile.d/segfault.sh && \
chmod 755 /usr /etc /etc/profile.d && \
chmod 644 /etc/profile.d/segfault.sh && \
chmod 644 /etc/shellrc /etc/zsh_command_not_found /etc/zsh_profile && \
ln -s batcat /usr/bin/bat && \
echo DONE || exit 254

