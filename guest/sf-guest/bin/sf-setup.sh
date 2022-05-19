#! /bin/bash

# Called when user's instance is booting up (created) and before
# the user shell is spawned.
# Called within sf-guest context.

# - Set up user's directories (if they dont exist already)
# - Execute /sec/usr/etc/rc.local

# NOTE: Possible that /sec/root etc already exists (old SECRET used after
# earlier instance exited) - in which case do nothing.

CR="\033[1;31m" # red
CN="\033[0m"    # none

ERREXIT()
{
	local code
	code="$1"
	[[ -z $code ]] && code=99

	shift 1
	[[ -n $1 ]] && echo -e >&2 "${CR}ERROR:${CN} $*"

	exit "$code"
}

if [[ -z $SF_DEBUG ]]; then
	DEBUGF(){ :;}
else
	DEBUGF(){ echo -e "${CY}DEBUG:${CN} $*";}
fi

mkhome()
{
	local dir
	local dirname
	local usergroup
	usergroup="$1"
	dirname="$2"

	dir="/sec/${dirname}"

	# e.g. /sec/root and /sec/home/user
	[[ -d "$dir" ]] && return # already exists

	DEBUGF "Creating /sec/${dirname}..."
	cp -a /etc/skel "${dir}"
	chown -R "${usergroup}" "${dir}"
	chmod 700 "${dir}"	
}

# rmsymdir src dst
# - Clear src and link to dst.
rmsymdir()
{
	local src
	local dst
	src="${1:-BAD}"
	dst="${2:-BAD}"

	# Remove old directory and symlink to /sec/home/user or /sec/root
	[[ -L "${src}" ]] && return # Already a sym-link
	[[ -e "${src}" ]] && rm -rf "${src}"

	ln -s "${dst}" "${src}"
}

setup_rclocal()
{
	mkdir -p /sec/usr/etc
	cp -a /usr/local/sf-guest/etc/rc.local /sec/usr/etc/rc.local
}

xmkdir()
{
	[[ -d "$1" ]] && return

	mkdir -p "$1"
}

# Setup the instance
# - Create home directories in /sec/root and /sec/home
# - 
setup()
{
	cd /
	[[ -d /sec ]] || ERREXIT 254 "Not found: /sec" # EncFS failed (?)

	# Setup home-directories to /sec
	mkhome root:root root
	[[ -d /sec/home ]] || mkdir /sec/home
	mkhome user:user home/user

	# Fix symlinks
	DEBUGF "Fixing symlinks..."
	rmsymdir /home /sec/home
	rmsymdir /root /sec/root
	rmsymdir /etc/rc.local /sec/usr/etc/rc.local

	# Create useful directory
	xmkdir /sec/usr/lib
	xmkdir /sec/usr/bin
	xmkdir /sec/usr/sbin
	xmkdir /sec/usr/share

	# Setup or execute rc.local
	[[ ! -f /sec/usr/etc/rc.local ]] && setup_rclocal || /bin/bash /sec/usr/etc/rc.local
}

DEBUGF "Setting up user's instance..."
setup

