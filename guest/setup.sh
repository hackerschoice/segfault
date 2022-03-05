#! /bin/bash

sed -i 's/#\(.*\)prompt_symbol=/\1prompt_symbol=/g' /etc/skel/.zshrc && \
sed -i 's/ set mouse=a/"set mouse=a/g' /usr/share/vim/vim82/defaults.vim && \

cp /etc/skel/.zshrc ~/ && \
chsh -s /bin/zsh
useradd  -s /bin/zsh user && \
cp -a /etc/skel /home/user && \
chown -R user:user /home/user && \
# Need to set correct permission which may have gotten skewed when building
# docker inside vmbox from shared host drive (rwxrwx--- root:vobxsf)
chown root:root /etc /etc/profile.d /etc/profile.d/l0pht.sh && \
chmod 755 /etc /etc/profile.d && \
chmod 644 /etc/profile.d/l0pht.sh && \
echo DONE

