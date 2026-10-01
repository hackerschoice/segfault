#! /bin/bash

export DEBIAN_FRONTEND=noninteractive
export PIPX_HOME=/usr
export PIPX_BIN_DIR=/usr/bin
export GNUPGHOME=/tmp
COPTS=("-SsfL" "--connect-timeout" "7" "-m900" "--retry" "3")

[[ -n $BESTEFFORT ]] && force_exit_code=0

# A positive limit collects failures across Docker RUN layers. Zero stays strict.
[[ ${SF_MAX_PACKAGE_FAILURES:-0} =~ ^[0-9]{1,6}$ ]] || {
	echo >&2 "Invalid SF_MAX_PACKAGE_FAILURES: expected a non-negative integer"
	exit 2
}
MAX_FAILURES=$((10#${SF_MAX_PACKAGE_FAILURES:-0}))
FAILURE_LOG="${SF_PACKAGE_FAILURES_FILE:-/var/log/sf-package-failures.tsv}"

failure_count()
{
	if [[ -f "$FAILURE_LOG" ]]; then
		wc -l <"$FAILURE_LOG"
	else
		echo 0
	fi
}

report_failures()
{
	local count
	count=$(failure_count)
	printf 'Package installation summary: %s failed (abort threshold: %s)\n' "$count" "$MAX_FAILURES"
	[[ ! -f "$FAILURE_LOG" ]] || awk -F '\t' '{ printf "%d. [%s] %s %s (exit %s)\n", NR, $4, $1, $2, $3 }' "$FAILURE_LOG"
	printf 'Failure report: %s\n' "$FAILURE_LOG"
}

check_failure_limit()
{
	if [[ $MAX_FAILURES -gt 0 && $(failure_count) -ge $MAX_FAILURES ]]; then
		report_failures >&2
		echo >&2 "Package failure threshold reached; aborting build."
		exit 100
	fi
}

# Upsert failures by installer and target; a successful retry removes that entry.
record_result()
{
	local rc="$1" kind="$2" target="$3" tmp count before
	[[ $MAX_FAILURES -gt 0 ]] || return 0
	[[ $rc -ne 0 || -f "$FAILURE_LOG" ]] || return 0
	[[ -z $GITHUB_TOKEN ]] || target=${target//"$GITHUB_TOKEN"/[REDACTED_GITHUB_TOKEN]}
	[[ -z $MAXMIND_KEY ]] || target=${target//"$MAXMIND_KEY"/[REDACTED_MAXMIND_KEY]}
	target=${target//$'\t'/\\t}
	target=${target//$'\n'/\\n}
	mkdir -p "$(dirname "$FAILURE_LOG")" || exit 2
	touch "$FAILURE_LOG" || exit 2
	before=$(failure_count)
	tmp=$(mktemp "${FAILURE_LOG}.XXXXXX") || exit 2
	SF_FAILURE_KEY="${kind}"$'\t'"${target}"$'\t' awk 'index($0, ENVIRON["SF_FAILURE_KEY"]) != 1' "$FAILURE_LOG" >"$tmp" || exit 2
	if [[ $rc -ne 0 ]]; then
		printf '%s\t%s\t%s\t%s\n' "$kind" "$target" "$rc" "$TAG" >>"$tmp" || exit 2
	fi
	mv "$tmp" "$FAILURE_LOG" || exit 2
	count=$(failure_count)
	if [[ $rc -ne 0 ]]; then
		printf >&2 'Package install failed [%s/%s]: [%s] %s %s (exit %s)\n' "$count" "$MAX_FAILURES" "$TAG" "$kind" "$target" "$rc"
	elif [[ $count -lt $before ]]; then
		printf >&2 'Package install recovered: %s %s\n' "$kind" "$target"
	fi
	check_failure_limit
}

[[ "$1" == --report ]] && {
	report_failures
	check_failure_limit
	exit 0
}
check_failure_limit

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

	[[ "${asset##*/}" != "$dass" ]] && {
		mv "${dstdir}"/${asset##*/} "${dstdir}/${dass}" || return
	}

	chmod 755 "${dstdir}/${dass}" || return
}

# Download & Extract
# [URL] [asset] <dstdir> <destination asset>
_dlx()
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

dlx() {
	_dlx "$@" || { echo >&2 "ERROR $*"; return 255; }
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
	local dstdir="$4"
	local dass="$5"
    local src
    src=$(dearch "$2") || exit 0
	asset=$(dearch "$3") || exit 0

	url=$(ghlatest "$1" "$src") || return

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

	url=$(ghlatest "$1" "$src") || return

	shift 1
	shift 1
	shift 1
	dlx "$url" "" "$dst" '' "$@"
}

bin()
{
	local url
	local asset="$2"
	local dstdir="$3"
	local dass="$4"

	url=$(dearch "$1") || exit 0

	shift 1
	shift 1
	shift 1
	shift 1
	dlx "$url" "$asset" "$dstdir" "$dass" "$@"
}

# A failed APT batch may prevent otherwise installable packages from being installed.
# Retry its packages separately, preserving options and recording each result.
apt_install()
{
	local rc=0 status package
	local -a command=("$1" "$2") options=() packages=() failed=()

	"$@" || rc=$?
	shift 2
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--)
				shift
				packages+=("$@")
				break
				;;
			-o|--option|-c|--config-file|-t|--target-release|--default-release|-a|--host-architecture|-P|--build-profiles|-S|--snapshot|--solver|--planner|--comment|--cli-version)
				[[ $# -ge 2 ]] || return "$rc"
				options+=("$1" "$2")
				shift 2
				;;
			-*)
				options+=("$1")
				shift
				;;
			*)
				packages+=("$1")
				shift
				;;
		esac
	done

	if [[ $rc -eq 0 || ${#packages[@]} -eq 1 ]]; then
		for package in "${packages[@]}"; do
			record_result "$rc" apt "$package"
		done
		[[ $MAX_FAILURES -gt 0 ]] && return 0
		return "$rc"
	fi
	[[ ${#packages[@]} -gt 1 ]] || return "$rc"
	printf >&2 'APT batch failed (%s); retrying %s packages individually.\n' "$rc" "${#packages[@]}"
	for package in "${packages[@]}"; do
		status=0
		"${command[@]}" "${options[@]}" -- "$package" || status=$?
		[[ $status -eq 0 ]] || failed+=("$package")
		record_result "$status" apt "$package"
	done

	[[ ${#failed[@]} -eq 0 ]] && return 0
	printf >&2 'Failed APT packages (%s):\n' "$TAG"
	local i
	for ((i=0; i<${#failed[@]}; i++)); do
		printf >&2 '%d. %s\n' "$((i + 1))" "${failed[i]}"
	done
	[[ $MAX_FAILURES -gt 0 ]] && return 0
	return "$rc"
}

TAG="${1^^}"
shift 1

# Can not use Dockerfile 'ARG SF_PACKAGES=${SF_PACKAGES:-"MINI BASE NET"}'
# because 'make' sets SF_PACKAGES to an _empty_ string and docker thinks
# an empty string does not warrant ':-"MINI BASE NET"' substititon.
[ -z "$SF_PACKAGES" ] && {
	SF_PACKAGES="MINI BASE NET"
	# if executed on segfault shell then assume ALL packages.
	[ -n "$SF_LID" ] && SF_PACKAGES="ALLALL"
}

[ -n "$SF_PACKAGES" ] && {
	SF_PACKAGES="${SF_PACKAGES^^}" # Convert to upper case
	[[ "$TAG" == *DISABLED* ]] && { echo "Skipping Packages: $TAG [DISABLED]"; exit; }
	[[ "$TAG" == ALLALL ]] && {
		[[ "$SF_PACKAGES" != *ALLALL* ]] && { echo "Skipping Packages: ALLALL"; exit; }
	}
	[[ "$SF_PACKAGES" != *ALL* ]] && [[ "$SF_PACKAGES" != *"$TAG"* ]] && { echo "Skipping Packages: $TAG"; exit; }
}

[[ "$1" == apt-get && "$2" == install ]] && {
	apt_install "$@"
	exit "${force_exit_code:-$?}"
}

# Helpers may exit internally; isolate them so their failure is still recorded.
rc=0
("$@") || rc=$?
printf -v target '%q ' "$@"
record_result "$rc" command "${target% }"
[[ $MAX_FAILURES -gt 0 ]] && exit 0
exit "${force_exit_code:-$rc}"
