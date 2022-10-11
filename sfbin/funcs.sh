
CY="\e[1;33m" # yellow
# CG="\e[1;32m" # green
CR="\e[1;31m" # red
CC="\e[1;36m" # cyan
# CM="\e[1;35m" # magenta
# CW="\e[1;37m" # white
CB="\e[1;34m" # blue
CF="\e[2m"    # faint
CN="\e[0m"    # none

# CBG="\e[42;1m" # Background Green

# night-mode
CDY="\e[0;33m" # yellow
CDG="\e[0;32m" # green
# CDR="\e[0;31m" # red
CDB="\e[0;34m" # blue
CDC="\e[0;36m" # cyan
CDM="\e[0;35m" # magenta
CUL="\e[4m"

ERR()
{
	echo -e >&2 "[${CR}ERROR${CN}] $*"
}

WARN()
{
	echo -e >&2 "[${CDY}WARN${CN}] $*"
}


ERREXIT()
{
	local code
	code="$1"

	shift 1
	ERR "$@"

	exit "$code"
}

if [[ -z $SF_DEBUG ]]; then
	DEBUGF(){ :;}
else
	DEBUGF(){ echo -e 1>&2 "${CY}DEBUG:${CN} $*";}
fi

