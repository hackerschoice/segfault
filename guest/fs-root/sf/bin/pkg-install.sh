#! /bin/bash

export DEBIAN_FRONTEND=noninteractive
export PIPX_HOME=/usr
export PIPX_BIN_DIR=/usr/bin

[[ -n $BESTEFFORT ]] && force_exit_code=0

# Substitute the string with correct architecture. E.g. we are 'x86_64'
# but filename contains 'amd64'. Also used to SKIP packages for specific
# architectures.
# str='lsd_.*_%arch%.deb$'
# str='lsd_.*_%arch:x86_64=amd64%.deb$'
# str='lsd_.*_%arch:x86_64=SKIP%.deb$'
# str='lsd_.*_%arch:x86_64=amd64:DEFAULT=SKIP%.deb$'
# str='lsd_.*_%arch:x86_64=amd64%.deb$ and linux-%arch:x86_64=amd64%.dat'
dearch()
{
	local str
    # Convert any '%arch%' to 'x86_64'
	str=${1//%arch%/$HOSTTYPE}
	[[ $str =~ %arch.*% ]] && {
        # Check if this specific architecture is set to be skipped.
		[[ $str =~ %arch:[^%]*$HOSTTYPE=SKIP ]] && { echo >&2 "Skipping. Not available for $HOSTTYPE."; return 255; }
        # Use translation table to convert 'x86_64' to 'amd64'
		str=$(echo "$str" | sed -e "s/%arch:[^%]*$HOSTTYPE=\([^:%]*\)[^%]*%/\1/g")
        [[ $str =~ %arch.*DEFAULT=SKIP% ]] && { echo >&2 "Skipping. Not available for $HOSTTYPE."; return 255; }
	}
    # ..and default is to set to ARCH value
    str=$(echo "$str" | sed -e "s/%arch:[^%]*%/$HOSTTYPE/g")
	echo "$str"
}

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

	[[ -z "$url" ]] && { echo >&2 "[${asset}] URL: '$loc'"; return 255; }
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
				chmod 755 "${dstdir}/$(basename "${asset}")" || return
			fi
			rm -f /tmp/pkg.zip \
			&& return 0
			;;
		*.deb)
			### Need to force-architecture as we install x86_64 only packages on aarch64
			curl -SsfL -o /tmp/pkg.deb "$url" \
			&& dpkg -i --force-architecture --ignore-depends=sshfs /tmp/pkg.deb \
			&& rm -rf /tmp/pkg.deb \
			&& return 0
			;;
		*.tar.gz|*.tgz)
			curl -SsfL "$url" | tar xfvz - --transform="flags=r;s|.*/||" --no-anchored  -C "${dstdir}" --wildcards "$asset" \
			&& chmod 755 "${dstdir}/${asset}" \
			&& return 0
			;;
		*.gz)
			curl -SsfL "$url" | gunzip >"${dstdir}/${asset}" \
			&& chmod 755 "${dstdir}/${asset}" \
			&& return 0
			;;
		*.tar.bz2)
			curl -SsfL "$url" | tar xfvj - --transform="flags=r;s|.*/||" --no-anchored  -C "${dstdir}" --wildcards "$asset" \
			&& chmod 755 "${dstdir}/${asset}" \
			&& return 0
			;;
		*.bz2)
			curl -SsfL "$url" | bunzip2 >"${dstdir}/${asset}" \
			&& chmod 755 "${dstdir}/${asset}" \
			&& return 0
			;;
		*.xz)
			curl -SsfL "$url" | tar xfvJ - --transform="flags=r;s|.*/||" --no-anchored  -C /usr/bin --wildcards "$asset" \
			&& chmod 755 "${dstdir}/${asset}" \
			&& return 0
			;;
		*)
			curl -SsfL "$url" >"${dstdir}/${asset}" \
			&& chmod 755 "${dstdir}/${asset}" \
			&& return 0
	esac
}

ghlatest()
{
	local loc
	local regex
	local args
	local data
	loc="$1"
	regex="$2"

	[[ -n $GITHUB_TOKEN ]] && args=("-H" "Authorization: Bearer $GITHUB_TOKEN")
	loc="https://api.github.com/repos/${loc}/releases/latest"
	data=$(curl "${args[@]}" -SsfL "$loc") || {
		echo >&2 "Failed($?) at '$loc'"
		[[ -z $GITHUB_TOKEN ]] && echo >&2 "Try setting GITHUB_TOKEN="
		exit 250
	}
	url=$(echo "$data" | jq -r '[.assets[] | select(.name|match("'"$regex"'"))][0] | .browser_download_url | select( . != null )')
	# url=$(curl "${args[@]}" -SsfL "$loc" | jq -r '[.assets[] | select(.name|match("'"$regex"'"))][0] | .browser_download_url | select( . != null )')
	[[ -z $url ]] && {
		echo >&2 "Asset '$regex' not found at '$loc'"
		exit 251
	}
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
    local src
    src=$(dearch "$2") || exit 0
	asset="$3"

	url=$(ghlatest "$1" "$src")
	dlx "$url" "$asset"
}

ghdir()
{
	local url
    local src
    src=$(dearch "$2") || exit 0

	url=$(ghlatest "$1" "$src")
	dlx "$url" "" "$3"
}

bin()
{
	local src
    src=$(dearch "$1") || exit 0

	dlx "$src" "$2"
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
	exit "${force_exit_code:-$?}"
}

[[ "$1" == ghdir ]] && {
	shift 1
	ghdir "$@"
	exit "${force_exit_code:-$?}"
}

[[ "$1" == ghlatest ]] && {
	shift 1
	ghlatest "$@"
	exit "${force_exit_code:-$?}"
}

[[ "$1" == bin ]] && {
	shift 1
	bin "$@"
	exit "${force_exit_code:-$?}"
}

#exec "$@"
"$@"
exit "${force_exit_code:-$?}"
