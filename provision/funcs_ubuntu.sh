
command -v apt-get >/dev/null || exit 255

PKG_UPDATE=(apt-get update -y)
PKG_INSTALL=(apt-get install -y)
IS_APT=1

install_sw()
{
  [[ -n $SF_NO_INTERNET ]] && return
  
  # Docker
  command -v docker >/dev/null || { bash -c "$(curl -fsSL https://get.docker.com)" || ERREXIT 255; }

  # Software
  "${PKG_INSTALL[@]}" docker-compose net-tools make || ERREXIT 138 "Docker not running"
}


pkg_clean()
{
	apt-get clean
	rm -rf /var/lib/apt/lists/*
}
