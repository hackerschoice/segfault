#! /bin/bash

[[ -t 1 ]] && {
CY="\e[1;33m" # yellow
CG="\e[1;32m" # green
CR="\e[1;31m" # red
CC="\e[1;36m" # cyan
CM="\e[1;35m" # magenta
CW="\e[1;37m" # white
CB="\e[1;34m" # blue
CF="\e[2m"    # faint
CN="\e[0m"    # none

# CBG="\e[42;1m" # Background Green

# night-mode
CDY="\e[0;33m" # yellow
CDG="\e[0;32m" # green
CDR="\e[0;31m" # red
CDB="\e[0;34m" # blue
CDC="\e[0;36m" # cyan
CDM="\e[0;35m" # magenta
CUL="\e[4m"

CRY="\e[0;33;41m"  # YELLOW on RED (warning)
}

ERREXIT() {
	[[ -n $1 ]] && echo -e >&2 "${CR}ERROR:${CN} $*"
	exit 255
}

# BINDIR="$(cd "$(dirname "${0}")" || exit; pwd)"
:
