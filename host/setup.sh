#! /bin/bash

echo "/bin/l0phtsh" >>/etc/shells && \
adduser -D ${LUSER} -s /bin/l0phtsh && \
sed -i 's/user\:!/user\:$6$nND1o68YSDG8heUr$wx\/FpC3\/TCZlhs3LsJ7ll5YVlPfICNN7yHmyppR6MqedvZ9Vgbq6SV3TlMFaFZAiYePNFaY477Xrb0fOMo24p0/g' /etc/shadow && \
# sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/g' /etc/ssh/sshd_config && \
# sed -i 's/#PrintMotd yes/ no/PermitEmptyPasswords yes/g' /etc/ssh/sshd_config && \

# Need to set correct permission which may have gotten skewed when building
# docker inside vmbox from shared host drive (rwxrwx--- root:vobxsf)
chown -R root:root /etc/ssh && \
chmod 700 /etc/ssh && \
chown root:root /bin/l0phtsh && \
chmod 755 /bin/l0phtsh && \
chmod 755 /bin /etc && \
echo DONE


