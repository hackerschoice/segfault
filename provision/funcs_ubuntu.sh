
command -v apt-get >/dev/null || exit 255

PKG_UPDATE=(apt-get update -y)
PKG_INSTALL=(apt-get install -y)
IS_APT=1

install_docker()
{
  command -v docker >/dev/null && return

  # Add docker repository to APT
  if [[ ! -s /usr/share/keyrings/docker-archive-keyring.gpg ]]; then
    [[ -z $SF_NO_INTERNET ]] && "${PKG_UPDATE[@]}" && "${PKG_INSTALL[@]}" --no-install-recommends ca-certificates \
      curl \
      gnupg \
      lsb-release \
      apt-transport-https

    [[ -s /usr/share/keyrings/docker-archive-keyring.gpg ]] || {
      rm -rf /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null # Delete in case it is zero bytes
      [[ -z $SF_NO_INTERNET ]] && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    }

    [[ -z $SF_NO_INTERNET ]] && "${PKG_UPDATE[@]}"
  fi

  ### Install Docker and supporting tools
  if [[ -z $SF_NO_INTERNET ]]; then
    apt-get install -y --no-install-recommends \
      docker-ce docker-ce-cli containerd.io docker-compose \
      net-tools make || ERREXIT 138 "Docker not running"
  fi
  docker ps >/dev/null || ERREXIT 
}

pkg_clean()
{
	apt-get clean
	rm -rf /var/lib/apt/lists/*
}
