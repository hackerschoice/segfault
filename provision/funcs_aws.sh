#! /bin/bash

[[ $(basename -- "$0") == "funcs_aws.sh" ]] && { echo "Use 'source funcs_aws.sh' instead."; exit 32; }

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

echo -e "${CDY}Create Filesystem and link SF-hirachy. Skip if already exists.${CN}"
echo -e "${CDY}Available Devices:${CN}"
lsblk -p | grep -v -F 'NAME'
echo -e "${CDY}Add the devices. Typical Example:${CN}
  ${CDC}aws_fs_add /dev/nvme1n1 /sf${CN}           # Normally the faster device
  ${CDC}aws_fs_add /dev/nvme2n1 /sf/config${CN}    # Normally a very small partition"
