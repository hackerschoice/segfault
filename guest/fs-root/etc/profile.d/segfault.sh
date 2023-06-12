# source'd during interactive shell login to SF-GUEST (e.g. bash -il, not bash -i)

_IS_SHOW_MOTD=1
[[ -z $PS1 ]] && unset _IS_SHOW_MOTD
[[ -n $SF_HUSHLOGIN ]] && unset _IS_SHOW_MOTD
[[ -z $SF_IS_LOGINSHELL ]] && unset _IS_SHOW_MOTD
[[ ! -f /sf/bin/sf-motd.sh ]] && unset _IS_SHOW_MOTD

# Trampoline to this script:
[[ -n $_IS_SHOW_MOTD ]] && {
	/sf/bin/sf-motd.sh
	[[ -f /config/guest/sys-motd.sh ]] && source /config/guest/sys-motd.sh
}
unset _IS_SHOW_MOTD
# No not display full info when using tmux or bash -il
unset SF_IS_NEW_SERVER
unset SF_IS_LOGINSHELL

# user on zsh and did `bash`
[[ -n $BASH ]] && export SHELL="/bin/bash"
[[ -n $ZSH_NAME ]] && {
	# user on bash and did `zsh -il`
	export SHELL="/bin/zsh"
	[[ -e /etc/zsh_profile ]] && . /etc/zsh_profile
}

[[ -z $COLORTERM ]] && export COLORTERM="truecolor"
[[ -e "/etc/cheat/conf.yml" ]] && export CHEAT_CONFIG_PATH="/etc/cheat/conf.yml"
[[ -z $EDITOR ]] && export EDITOR="vim"
