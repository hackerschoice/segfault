#! /bin/bash

export DEBIAN_FRONTEND=noninteractive
export PIPX_HOME=/usr
export PIPX_BIN_DIR=/usr/bin
COPTS=("-SsfL" "--connect-timeout" "7" "-m900" "--retry" "3")

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
	local ht

	# 'lsd_.*_%arch1%.deb$' ==> lsd_.*_amd64.deb
	[[ $1 =~ %arch1% ]] && {
		[[ $HOSTTYPE == x86_64 ]] && ht="amd64"
		[[ $HOSTTYPE == aarch64 ]] && ht="arm64"
		echo "${1//%arch1%/$ht}"
		return
	}

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

xmv() {
	local asset
	local dass
	local dstdir
	asset="$1"
	dass="$2"
	dstdir="$3"

	[[ "$asset" != "$dass" ]] && {
		mv "${dstdir}"/${asset} "${dstdir}/${dass}" || return
	}

	chmod 755 "${dstdir}/${dass}" || return
}

# Download & Extract
# [URL] [asset] <dstdir> <destination asset>
dlx()
{
	local url
	local asset
	local dstdir
	local dass
	url="$1"
	asset="$2"  # May contain wildcards/Need globbing
	dstdir="$3"
	dass="$4"
	# Cant do 'shift 4' here because that wont shift _AT ALL_
	# if parameters are less than 4.
	shift 1
	shift 1
	shift 1
	shift 1
	
	[[ -z $dstdir ]] && dstdir="/usr/bin"
	[[ -z $dass ]] && dass="$asset"

	[[ -z "$url" ]] && { echo >&2 "[${asset}] URL: '$loc'"; return 255; }
	case $url in
		*.zip)
			[[ -f /tmp/pkg.zip ]] && rm -f /tmp/pkg.zip
			curl "${COPTS[@]}" -o /tmp/pkg.zip "$url" || return
			if [[ -z $asset ]]; then
				# HERE: Directory
				unzip /tmp/pkg.zip -d "${dstdir}" || return
			else
				# HERE: Single file
				{ unzip -o -j /tmp/pkg.zip "$asset" -d "${dstdir}" \
				&& xmv "$asset" "$dass" "$dstdir"; } || return
			fi
			rm -f /tmp/pkg.zip \
			&& return 0
			;;
		*.deb)
			### Need to force-architecture as we install x86_64 only packages on aarch64
			## Shitty packages like watchexec need --force-overwrite in $@ to overwrite watchexec.fish (which already exists)
			curl "${COPTS[@]}" -o /tmp/pkg.deb "$url" \
			&& dpkg -i --force-architecture "$@" --ignore-depends=sshfs /tmp/pkg.deb \
			&& rm -rf /tmp/pkg.deb \
			&& return 0
			;;
		*.tar.gz|*.tgz)
			curl "${COPTS[@]}" "$url" | tar xfvz - --transform="flags=r;s|.*/||" --no-anchored  -C "${dstdir}" --wildcards "$asset" \
			&& xmv "$asset" "$dass" "$dstdir" \
			&& return 0
			;;
		*.gz)
			curl "${COPTS[@]}" "$url" | gunzip >"${dstdir}/${asset}" \
			&& chmod 755 "${dstdir}/${dass}" \
			&& return 0
			;;
		*.tar.bz2)
			curl "${COPTS[@]}" "$url" | tar xfvj - --transform="flags=r;s|.*/||" --no-anchored  -C "${dstdir}" --wildcards "$asset" \
			&& xmv "$asset" "$dass" "$dstdir" \
			&& return 0
			;;
		*.bz2)
			curl "${COPTS[@]}" "$url" | bunzip2 >"${dstdir}/${asset}" \
			&& xmv "$asset" "$dass" "$dstdir" \
			&& return 0
			;;
		*.xz)
			curl "${COPTS[@]}" "$url" | tar xfvJ - --transform="flags=r;s|.*/||" --no-anchored  -C /usr/bin --wildcards "$asset" \
			&& xmv "$asset" "$dass" "$dstdir" \
			&& return 0
			;;
		*)
			curl "${COPTS[@]}" "$url" >"${dstdir}/${asset}" \
			&& chmod 755 "${dstdir}/${dass}" \
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
	data=$(curl "${COPTS[@]}" "${args[@]}" "$loc") || {
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
	local dstdir
	local dass
    local src
    src=$(dearch "$2") || exit 0
	asset=$(dearch "$3") || exit 0
	dstdir="$4"
	dass="$5"

	url=$(ghlatest "$1" "$src")

	shift 1
	shift 1
	shift 1
	shift 1
	shift 1
	dlx "$url" "$asset" "$dstdir" "$dass" "$@"
}

ghdir()
{
	local url
    local src
	local dst="$3"
    src=$(dearch "$2") || exit 0

	url=$(ghlatest "$1" "$src")

	shift 1
	shift 1
	shift 1
	dlx "$url" "" "$dst" '' "$@"
}

bin()
{
	local url
	local asset="$2"

    url=$(dearch "$1") || exit 0

	shift 1
	shift 1
	dlx "$url" "$asset" '' '' "$@"
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
