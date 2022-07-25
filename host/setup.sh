#! /bin/bash

# Docker sf-host setup script (docker build)

ROOTUSER="root"
# Default is for user to use 'ssh root@segfault.net' but this can be changed
# in .env to any other user name. In case it is 'root' then we need to move
# the true root out of the way for the docker-sshd to work.
if [[ "$SF_USER" = "root" ]]; then
	# rename root user
	sed -i 's/^root/toor/' /etc/passwd
	sed -i 's/^root/toor/' /etc/shadow
fi
echo "/bin/segfaultsh" >>/etc/shells && \
adduser -D "${SF_USER}" -G nobody -s /bin/segfaultsh && \
echo "${SF_USER}:${SF_USER_PASSWORD}" | chpasswd
# sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/g' /etc/ssh/sshd_config && \
# sed -i 's/#PrintMotd yes/ no/PermitEmptyPasswords yes/g' /etc/ssh/sshd_config && \

# Need to set correct permission which may have gotten skewed when building
# docker inside vmbox from shared host drive (rwxrwx--- root:vobxsf)
chown -R "${ROOTUSER}":"${ROOTUSER}" /etc/ssh && \
chmod 700 /etc/ssh && \
chown "${ROOTUSER}":"${ROOTUSER}" /bin/segfaultsh && \
chmod 755 /bin/segfaultsh && \
chmod 755 /bin /etc && \
echo DONE
