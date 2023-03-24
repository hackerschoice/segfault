#! /bin/bash

# Called when guest instance is booting up (created) and before
# the user shell is spawned.
# Called within sf-guest context.

# - Set up user's directories (if they dont exist already)
# - Execute /sec/usr/etc/rc.local

# NOTE: Possible that /sec/root etc already exists (old SECRET used after
# earlier instance exited) - in which case do nothing.

CR="\e[1;31m" # red
CN="\e[0m"    # none

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
	# /sec/root must already exist because docker-run needs --workdir=/sec/root
	# and docker internally creates this directory. Instead check of .zshrc
	# [[ -d "$dir" ]] && return # already exists

	[[ -f "${dir}/.zshrc" ]] && return
	DEBUGF "Creating /sec/${dirname}..."
	rsync -a /etc/skel/ "${dir}"
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
	cp -a /etc/rc.local-example /sec/usr/etc/rc.local
}

xmkdir()
{
	[[ -d "$1" ]] && return

	mkdir -p "$1"
}

link_etc()
{
	[[ ! -d /sec/usr/etc ]] && mkdir -p /sec/usr/etc

	cd /sec/usr/etc || return
	for fn in ./*; do
		[[ ! -e "$fn" ]] && break
		[[ "/etc/${fn}" -ef "${fn}" ]] && continue # Already linked
		[[ -e "/etc/${fn}" ]] && rm -rf "/etc/${fn:?}"
		DEBUGF "Linking /etc/${fn} -> /sec/usr/etc/${fn}"
		ln -sf "/sec/usr/etc/${fn}" "/etc/${fn}"
	done
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

	# Create useful directory
	xmkdir /dev/shm/tmp && chmod 1777 /dev/shm/tmp
	xmkdir /sec/usr/lib
	xmkdir /sec/usr/bin
	xmkdir /sec/usr/sbin
	xmkdir /sec/usr/share/cheatsheets/personal

	# Copy Pelican www
	[[ ! -d /sec/www ]] && {
		cp -a /usr/share/www /sec
		sed "s/^SITEURL.*/SITEURL = '\/${SF_HOSTNAME,,}'/" -i /sec/www/pelicanconf.py
	}

	# Setup rc.local (if not exist)
	[[ ! -f /sec/usr/etc/rc.local ]] && setup_rclocal
	# Link any /etc/* file to /sec/usr/etc if it exists...
	link_etc
	# Execute rc.local startup script
	/bin/bash /sec/usr/etc/rc.local

	return 0 # TRUE
}

DEBUGF "Setting up user's instance..."
setup

