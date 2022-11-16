
command -v apt-get >/dev/null || exit 255

PKG_UPDATE=(apt-get update -y)
PKG_INSTALL=(apt-get install -y)
IS_APT=1

install_sw()
{
  command -v docker >/dev/null && return
  # Docker
  bash -c "$(curl -fsSL https://get.docker.com)" || ERREXIT 255

  # Software
  if [[ -z $SF_NO_INTERNET ]]; then
    "${PKG_INSTALL[@]}" docker-compose net-tools make || ERREXIT 138 "Docker not running"
  fi
}


pkg_clean()
{
	apt-get clean
	rm -rf /var/lib/apt/lists/*
}
