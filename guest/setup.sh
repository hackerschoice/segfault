#! /bin/bash

# Docker sf-guest setup script (docker build)

sed -i 's/#\(.*\)prompt_symbol=/\1prompt_symbol=/g' /etc/skel/.zshrc && \
sed -i 's/ set mouse=a/"set mouse=a/g' /usr/share/vim/vim82/defaults.vim && \
rm -f /usr/bin/kali-motd && \
chsh -s /bin/zsh
useradd  -s /bin/zsh user && \
sed -i 's/\/root/\/sec\/root/g' /etc/passwd && \
sed -i 's/\/home\//\/sec\/home\//g' /etc/passwd && \
# Docker depends on /root to exist or otherwise throws a:
# [process_linux.go:545: container init caused: mkdir /root: file exists: unknown]
#
# Need to set correct permission which may have gotten skewed when building
# docker inside vmbox from shared host drive (rwxrwx--- root:vobxsf)
chown root:root /etc /etc/profile.d /etc/profile.d/segfault.sh && \
chmod 755 /etc /etc/profile.d && \
chmod 644 /etc/profile.d/segfault.sh && \
echo DONE

