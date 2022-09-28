#! /bin/bash

[[ $(basename -- "$0") == "aws.sh" ]] && { echo "Use 'source aws.sh' instead."; exit 32; }

SFI_SRCDIR="$(cd "$(dirname "${BASH_ARGV[0]}")/.." || return; pwd)"

source "${SFI_SRCDIR}/provision/system/funcs" || return

# fs_add <device> <mount point>
aws_fs_add()
{
	local dev
	local mp
	dev="$1"
	mp="$2"

	[[ ! -e "${dev:?}" ]] && return

	blkid "${dev}" >/dev/null || {
		# No FS exists. Make it.
		mkfs -t xfs "${dev}" || return
	}
	eval FS_$(blkid "${dev}" | cut -f2-2 -d' ')
	grep -F "${FS_UUID:?}" /etc/fstab >/dev/null || {
		echo -e "UUID=${FS_UUID}     ${mp:0:12}    xfs    defaults,nofail,noatime,usrquota,prjquota 1 2" >>/etc/fstab
	}
	[[ ! -d "${mp}" ]] && { mkdir -p "${mp}" || return; }
	mountpoint -q "${mp}" || { mount "${mp}" || return; }
	echo "${dev} provisioned to ${mp}"
}

# _aws_mkdirln [name] <list of dirs to try>
# _aws_mkdirln()
# {
# 	local fn
# 	local speed
# 	fn="$1"

# 	# Dedicated EBS for this fn (e.g. /sf/docker)
# 	[[ -d "/sf/${fn}" ]] && return

# 	shift 1

# 	for dst in "$@"; do
# 		[[ ! -d "/sf/${dst}" ]] && continue
# 		mountpoint -q "/sf/${dst}" || return # Not a mount point.
# 		[[ ! -d "/sf/${dst}/${fn}" ]] && mkdir -p "/sf/${dst}/${fn}"
# 		ln -s "/sf/${dst}/${fn}" "/sf/${fn}"
# 		return
# 	done
# 	mkdir -p "/sf/${fn}"
# }

# # Create all directories
# aws_fs_done()
# {
# 	[[ ! -d /sf ]] && return

# 	# Link the directories that segfault-on-aws expects	
# 	# /sf/docker is either on /sf/docker or /sf/fast/docker but
# 	# never on /sf or /sf/slow
# 	_aws_mkdirln "docker" fast 
# 	_aws_mkdirln "config" fast slow
# 	_aws_mkdirln "data" slow fast
# }
[[ "${UID}" -ne 0 ]] && { echo >&2 "Need root"; exit 255; }

echo -e "${CDY}Create Filesystem and link SF-hirachy. Skip if already exists.${CN}"
echo -e "${CDY}Available Devices:${CN}"
lsblk -p | grep -v -F 'NAME'
echo -e "${CDY}Add the devices. Typical Example:${CN}
  ${CDC}aws_fs_add /dev/nvme1n1 /sf/docker${CN}    # Normally the faster (but smaller) device
  ${CDC}aws_fs_add /dev/nvme2n1 /sf/data${CN}      # Normally the slower (but larger) device
  ${CDC}aws_fs_add /dev/nvme3n1 /sf/config${CN}    # Normally a very small partition"
# ${CDY}Then finish with:${CN}
  # ${CDC}aws_fs_done${CN}"

# Find all devices without FS
# for dev in $(lsblk -dpbr | grep '^/dev' | cut -f1 -d' '); do
# 	mount | grep -F "${dev}" >/dev/null && continue
# 	[[ ! -e "${dev}" ]] && { echo "Not found: '${dev}'"; continue; }
# 	blkid "${dev}" && continue  # FS already exists
# 	arr=($(lsblk -bPp "${dev}"))
# 	eval FS_${arr[3]}
# 	fs_dev+=($dev)
# 	fs_size+=($FS_SIZE)
# done
