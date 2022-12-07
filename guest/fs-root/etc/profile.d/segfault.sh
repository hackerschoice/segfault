# source'd during interactive shell login to SF-GUEST (e.g. bash -il, not bash -i)

# Trampoline to this script:
[[ -f /sf/bin/sf-motd.sh ]] && [[ -n "$SF_IS_LOGINSHELL" ]] && {
	/sf/bin/sf-motd.sh
	[[ -f /config/guest/sys-motd.sh ]] && source /config/guest/sys-motd.sh
	unset SF_IS_LOGINSHELL # Only display motd on ssh login but not zsh -il or su - user
}

[[ -n $BASH ]] && {
	# user on zsh and did `bash -il`
	export SHELL="/bin/bash"
}

[[ -n $ZSH_NAME ]] && {
	# user on bash and did `zsh -il`
	export SHELL=/bin/zsh
	[[ -e /etc/zsh_profile ]] && . /etc/zsh_profile
}

[[ -z $COLORTERM ]] && export COLORTERM=truecolor
[[ -e "/etc/cheat/conf.yml" ]] && export CHEAT_CONFIG_PATH="/etc/cheat/conf.yml"
export EDITOR=vim
