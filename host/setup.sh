#! /bin/bash


# Fixing vmbox permissions
chmod 755 /etc /usr /bin /bin/segfaultsh /bin/webshellsh /bin/asksecsh /bin/mmdbinspect /bin/docker-exec-sigproxy
chmod 644 /etc/english.txt

echo -e "/bin/segfaultsh\n/bin/webshellsh" >>/etc/shells

