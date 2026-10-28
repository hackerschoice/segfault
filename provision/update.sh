#! /bin/bash

# Admin Tool - Update /sf/bin and other directories
# Called when upgrading a version of segfault without going
# through a full reinstall and showing the difference
#
# make
# provison/update.sh


SFI_SRCDIR="$(cd "$(dirname "${0}")/.." || exit; pwd)"
# shellcheck disable=SC1091
source "${SFI_SRCDIR}/provision/system/funcs" || exit 255
NEED_ROOT

ENV_LOAD "${SFI_SRCDIR}/.env" add || ERREXIT 250 "Failed to load .env"

[[ -z $SF_BASEDIR ]] && ERREXIT 255 "SF_BASEDIR= not set"
[[ ! -d "$SF_BASEDIR" ]] && ERREXIT 255 "Directory not found (SF_BASEDIR=): $SF_BASEDIR"

# [mode] [file] [dest-file]
merge_file()
{
	local mode
	local sfn
	local dfn
	mode="$1"
	sfn="$2"
	dfn="$3"

	[[ -d "${dfn}" ]] && ERREXIT 240 "Not a file: ${dfn}"
	[[ -d "${sfn}" ]] && ERREXIT 240 "Not a file: ${sfn}"

	(
		IFS=""
		[[ "${sfn}" -ef "${dfn}" ]] && return # Symlink
		[[ -e "${dfn}" || -L "${dfn}" ]] && {
			# Already installed
			[[ $mode == "diff" ]] && {
				# Comment-only templates have no active settings to preserve.
				if [[ -f $sfn && -f $dfn ]] && ! grep -qEv '^[[:space:]]*(#|$)' "$sfn" && ! grep -qEv '^[[:space:]]*(#|$)' "$dfn"; then
					cp -p "$sfn" "$dfn" || ERREXIT 240 "Cannot update $dfn"
					return
				fi
				res=$(diff --color=always -u "${dfn}" "${sfn}")
				[[ $? -gt 1 ]] && ERREXIT 240 "diff failed"
				[[ -z $res ]] && return
				echo -e "${CDY}Please merge ${CY}${sfn}${CN} -> ${CY}${dfn}${CN}"
				echo "$res"
				return
			}
			[[ $mode == "force" ]] && {
				# Return if identical (no update needed)
				[[ $(MD5F "$sfn") == $(MD5F "${dfn}") ]] && return
			}
		}
		echo -e "${CDG}Installing ${CG}${dfn}${CDG}...${CN}"
		mkdir -p "$(dirname "${dfn}")" || ERREXIT
		cp -a "${sfn}" "${dfn}" || ERREXIT
	)
}

merge()
{
	local mode
	local sdir
	local ddir
	mode="$1"
	sdir="$2"
	ddir="$3"

	cd "${sdir}" || ERREXIT 255
	find . -type f | while read f; do
		merge_file "${mode}" "${f}" "${ddir}/${f}"
	done
}

merge_file force "${SFI_SRCDIR}/config/etc/sf/WARNING---SHARED-BETWEEN-ALL-SERVERS---README.txt" "${SF_BASEDIR}/config/etc/sf/WARNING---SHARED-BETWEEN-ALL-SERVERS---README.txt"
merge_file force "${SFI_SRCDIR}/config/etc/hosts" "${SF_BASEDIR}/config/etc/hosts"
merge force "${SFI_SRCDIR}/sfbin" "${SF_BASEDIR}/sfbin"
merge_file force "${SFI_SRCDIR}/contrib/cronjob" "${SF_BASEDIR}/sfbin/cronjob"
merge diff "${SFI_SRCDIR}/config" "${SF_BASEDIR}/config"
merge_file diff "${SFI_SRCDIR}/provision/env.example" "${SFI_SRCDIR}/.env"
