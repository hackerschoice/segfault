
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
	echo -e >&2 "[$(date '+%F %T' -u)] [${CR}ERROR${CN}] $*"
}

WARN()
{
	((IS_WARN++))
	echo -e >&2 "[$(date '+%F %T' -u)] [${CDY}#${IS_WARN} WARN${CN}] $*"
}

WARN_RESET()
{
	unset IS_WARN
}

LOG()
{
	local lid
	lid="$1"

	shift 1
	echo -e "[$(date '+%F %T' -u)] [${CDM}${lid}${CN}] $*"
}

ERREXIT()
{
	local code
	code="$1"

	shift 1
	ERR "$@"

	exit "$code"
}

SLEEPEXIT()
{
	local code
	local s
	code="$1"
	s="$1"

	shift 2

	ERR "$@"

	slee "$s"
	exit "$code"
}

if [[ -z $SF_DEBUG ]]; then
	DEBUGF(){ :;}
else
	DEBUGF(){ echo -e 1>&2 "${CY}DEBUG:${CN} $*";}
fi

WARN_ENTER()
{
	[[ -z $IS_WARN ]] && return
	unset IS_WARN

	echo "Press Enter to continue. Aborting in 10 seconds otherwise..."
	read -t 10 || ERREXIT 255 "Aborting. User did not press Enter."
}
