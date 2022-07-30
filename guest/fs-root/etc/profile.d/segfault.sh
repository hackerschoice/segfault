# source'd during interactive shell login to SF-GUEST.

# Trampoline to this script:
[[ -e /sf/bin/sf-motd.sh ]] && /sf/bin/sf-motd.sh

[[ -n $ZSH_NAME ]] && {
	[[ -z $SHELL ]] && export SHELL=/bin/zsh
	[[ -e /etc/zsh_profile ]] && . /etc/zsh_profile
}