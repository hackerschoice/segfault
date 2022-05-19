#! /bin/bash

# Docker sf-guest setup script (docker build)

sed -i 's/#\(.*\)prompt_symbol=/\1prompt_symbol=/g' /etc/skel/.zshrc && \
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
# ln -sf /sec/root /root && \
#
# Need to set correct permission which may have gotten skewed when building
# docker inside vmbox from shared host drive (rwxrwx--- root:vobxsf)
ln -sf /sec/usr/etc/rc.local /etc/rc.local && \
chown root:root /etc /etc/profile.d /etc/profile.d/segfault.sh && \
chmod 755 /etc /etc/profile.d && \
chmod 644 /etc/profile.d/segfault.sh && \
chmod 644 /etc/shellrc && \
ln -s batcat /usr/bin/bat && \
curl -fsSL https://github.com/Peltoche/lsd/releases/download/0.21.0/lsd_0.21.0_amd64.deb -o /tmp/lsd.dep && \
dpkg -i /tmp/lsd.dep && \
echo DONE || exit 254

