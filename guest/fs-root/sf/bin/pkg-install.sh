#! /bin/bash

export DEBIAN_FRONTEND=noninteractive
export PIPX_HOME=/usr
export PIPX_BIN_DIR=/usr/bin

# Download & Extract
# [URL] [asset] <dstdir>
dlx()
{
	local url
	local asset
	local dstdir
	url="$1"
	asset="$2"
	dstdir="$3"
	[[ -z $dstdir ]] && dstdir="/usr/bin"

	[[ -z "$url" ]] && { echo >&2 "URL: '$loc'"; return 255; }
	case $url in
		*.zip)
			[[ -f /tmp/pkg.zip ]] && rm -f /tmp/pkg.zip
			curl -SsfL -o /tmp/pkg.zip "$url" || return
			if [[ -z $asset ]]; then
				# HERE: Directory
				unzip /tmp/pkg.zip -d "${dstdir}" || return
			else
				# HERE: Single file
				unzip -o -j /tmp/pkg.zip "$asset" -d "${dstdir}" || return
				chmod 755 "${dstdir}/${asset}" || return
			fi
			rm -f /tmp/pkg.zip \
			&& return 0
			;;
		*.deb)
			curl -SsfL -o /tmp/pkg.deb "$url" \
			&& dpkg -i --ignore-depends=sshfs /tmp/pkg.deb \
			&& rm -rf /tmp/pkg.deb \
			&& return 0
			;;
		*.tar.gz|*.tgz)
			curl -SsfL "$url" | tar xfvz - --transform="flags=r;s|.*/||" --no-anchored  -C "${dstdir}" "$asset" \
			&& chmod 755 "${dstdir}/${asset}" \
			&& return 0
			;;
		*.gz)
			curl -SsfL "$url" | gunzip >"${dstdir}/${asset}" \
			&& chmod 755 "${dstdir}/${asset}" \
			&& return 0
			;;
		*.tar.bz2)
			curl -SsfL "$url" | tar xfvj - --transform="flags=r;s|.*/||" --no-anchored  -C "${dstdir}" "$asset" \
			&& chmod 755 "${dstdir}/${asset}" \
			&& return 0
			;;
		*.bz2)
			curl -SsfL "$url" | bunzip2 >"${dstdir}/${asset}" \
			&& chmod 755 "${dstdir}/${asset}" \
			&& return 0
			;;
		*.xz)
			curl -SsfL "$url" | tar xfvJ - --transform="flags=r;s|.*/||" --no-anchored  -C /usr/bin "$asset" \
			&& chmod 755 "${dstdir}/${asset}" \
			&& return 0
			;;
		*)
			curl -SsfL "$url" >"${dstdir}/${asset}" \
			&& chmod 755 "${dstdir}/${asset}" \
			&& return 0
			# echo >&2 "Unknown file extension in '$url'"
	esac
}

ghlatest()
{
	local loc
	local regex
	local args
	loc="$1"
	regex="$2"

	[[ -n $GITHUB_TOKEN ]] && args=("-H" "Authorization: Bearer $GITHUB_TOKEN")
	loc="https://api.github.com/repos/${loc}/releases/latest"
	url=$(curl "${args[@]}" -SsfL "$loc" | jq -r '[.assets[] | select(.name|match("'"$regex"'"))][0] | .browser_download_url | select( . != null )')
	[[ -z $url ]] && return 251
	echo "$url"
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
	local url
	local asset
	asset="$3"

	url=$(ghlatest "$1" "$2") || { echo >&2 "Try setting GITHUB_TOKEN=..."; return 255; }
	dlx "$url" "$asset"
}

ghdir()
{
	local url

	url=$(ghlatest "$1" "$2") || { echo >&2 "Try setting GITHUB_TOKEN=..."; return 255; }
	dlx "$url" "" "$3"
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

[[ "$1" == ghdir ]] && {
	shift 1
	ghdir "$@"
	exit
}

[[ "$1" == ghlatest ]] && {
	shift 1
	ghlatest "$@"
	exit
}

[[ "$1" == bin ]] && {
	shift 1
	bin "$@"
	exit
}

exec "$@"
