#! /bin/bash

export DEBIAN_FRONTEND=noninteractive
export PIPX_HOME=/usr
export PIPX_BIN_DIR=/usr/bin

# Download & Extract
# [URL] [asset]
dlx()
{
	local url
	local asset
	url="$1"
	asset="$2"

	[[ -z "$url" ]] && { echo >&2 "URL: '$loc'"; return 255; }
	case $url in
		*.zip)
			[[ -f /tmp/pkg.zip ]] && rm -f /tmp/pkg.zip
			curl -SsfL -o /tmp/pkg.zip "$url" \
			&& unzip -o -j /tmp/pkg.zip "$asset" -d /usr/bin \
			&& chmod 755 "/usr/bin/${asset}" \
			&& rm -f /tmp/pkg.zip \
			&& return 0
			;;
		*.deb)
			curl -SsfL -o /tmp/pkg.deb "$url" \
			&& dpkg -i /tmp/pkg.deb \
			&& rm -rf /tmp/pkg.deb \
			&& return 0
			;;
		*.tar.gz|*.tgz)
			curl -SsfL "$url" | tar xfvz - --transform="flags=r;s|.*/||" --no-anchored  -C /usr/bin "$asset" \
			&& chmod 755 "/usr/bin/${asset}" \
			&& return 0
			;;
		*.gz)
			curl -SsfL "$url" | gunzip >"/usr/bin/${asset}" \
			&& chmod 755 "/usr/bin/${asset}" \
			&& return 0
			;;
		*.tar.bz2)
			curl -SsfL "$url" | tar xfvj - --transform="flags=r;s|.*/||" --no-anchored  -C /usr/bin "$asset" \
			&& chmod 755 "/usr/bin/${asset}" \
			&& return 0
			;;
		*.bz2)
			curl -SsfL "$url" | bunzip2 >"/usr/bin/${asset}" \
			&& chmod 755 "/usr/bin/${asset}" \
			&& return 0
			;;
		*.xz)
			curl -SsfL "$url" | tar xfvJ - --transform="flags=r;s|.*/||" --no-anchored  -C /usr/bin "$asset" \
			&& chmod 755 "/usr/bin/${asset}" \
			&& return 0
			;;
		*)
			curl -SsfL "$url" >"/usr/bin/${asset}" \
			&& chmod 755 "/usr/bin/${asset}" \
			&& return 0
			# echo >&2 "Unknown file extension in '$url'"
	esac
}

# Install latest Binary from GitHub and smear it into /usr/bin
# [<user>/<repo>] [<regex-match>] [asset]
# Examples:
# ghbin tomnomnom/waybackurls "linux-amd64-" waybackurls 
# ghbin SagerNet/sing-box "linux-amd64." sing-box
# ghbin projectdiscovery/httpx "linux_amd64.zip$" httpx 
# ghbin Peltoche/lsd "lsd_.*_amd64.deb$" 
ghbin()
{
	local loc
	local regex
	local url
	local asset
	loc="$1"
	regex="$2"
	asset="$3"

	loc="https://api.github.com/repos/${loc}/releases/latest"
	url=$(curl -SsfL "$loc" | jq -r '[.assets[] | select(.name|match("'"$regex"'"))][0] | .browser_download_url | select( . != null )')
	dlx "$url" "$asset"
}

bin()
{
	dlx "$1" "$2"
}


TAG="${1^^}"
shift 1

# Can not use Dockerfile 'ARG SF_PACKAGES=${SF_PACKAGES:-"MINI BASE NET"}'
# because 'make' sets SF_PACKAGES to an _empty_ string and docker thinks
# an empty string does not warrant ':-"MINI BASE NET"' substititon.
[[ -z $SF_PACKAGES ]] && SF_PACKAGES="MINI BASE NET"

[[ -n $SF_PACKAGES ]] && {
	SF_PACKAGES="${SF_PACKAGES^^}" # Convert to upper case
	[[ "$TAG" == *DISABLED* ]] && { echo "Skipping Packages: $TAG [DISABLED]"; exit; }
	[[ "$TAG" == ALLALL ]] && {
		[[ "$SF_PACKAGES" != *ALLALL* ]] && { echo "Skipping Packages: ALLALL"; exit; }
	}
	[[ "$SF_PACKAGES" != *ALL* ]] && [[ "$SF_PACKAGES" != *"$TAG"* ]] && { echo "Skipping Packages: $TAG"; exit; }
}

[[ "$1" == ghbin ]] && {
	shift 1
	ghbin "$@"
	exit
}

[[ "$1" == bin ]] && {
	shift 1
	bin "$@"
	exit
}

exec "$@"
