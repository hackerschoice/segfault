#! /bin/bash


# Fixing vmbox permissions
chmod 755 /etc /usr /bin /bin/segfaultsh /bin/webshellsh
chmod 644 /etc/english.txt

echo -e "/bin/segfaultsh\n/bin/webshellsh" >>/etc/shells

