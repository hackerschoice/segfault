

command -v yum >/dev/null || exit 255

PKG_UPDATE=(yum update -y)
PKG_INSTALL=(yum install -y)
IS_YUM=1

install_docker()
{
	command -v docker >/dev/null || "${PKG_INSTALL[@]}" docker || ERREXIT

	command -v docker-compose >/dev/null || {
		curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
		chmod +x /usr/local/bin/docker-compose
	}
}

pkg_clean()
{
	yum clean all
	rm -rf /var/cache/yum
	rm -rf /var/tmp/yum*
}