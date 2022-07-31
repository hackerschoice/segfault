# source'd during interactive shell login to SF-GUEST.

# Trampoline to this script:
[[ -e /sf/bin/sf-motd.sh ]] && [[ -n "$SF_IS_LOGINSHELL" ]] && {
	/sf/bin/sf-motd.sh
	unset SF_IS_LOGINSHELL # Only display motd on ssh login but not zsh -il or su - user
}

[[ -n $ZSH_NAME ]] && {
	[[ -z $SHELL ]] && export SHELL=/bin/zsh
	[[ -e /etc/zsh_profile ]] && . /etc/zsh_profile
}