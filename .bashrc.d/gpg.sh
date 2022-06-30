#!/usr/bin/env bash

## ------------------------------------------------------------------------ ##
##  .bashrc.d/gpg.sh                         Nicholas Berlette, 2022-06-30  ##
## ------------------------------------------------------------------------ ##
##  https://github.com/nberlette/dotfiles/blob/main/.bashrc.d/gpg.sh        ##
## ------------------------------------------------------------------------ ##

export GPG_TTY=$(tty)

function get_json()
{
	local path file
	file="${1:-"/workspace/.vscode-remote/settings.json"}"
	path="${2:-git.enableCommitSigning}"
	# quotemageddon
	jq '.["'"$path"'"]' "$file" 2> /dev/null || return $?
}

function set_json()
{
	local path value file
	file="${1:-"/workspace/.vscode-remote/settings.json"}"
	path="${2:-git.enableCommitSigning}"
	value="${3:-true}"
	# holy freakin quotes batman
	jq '.["'"$path"'"]='"$value"' | .' "$file" 2> /dev/null || return $?
}

function __gpg_gitconfig()
{
	git config --global user.name "${GIT_COMMITTER_NAME:-"$(git config user.name)"}"
	git config --global user.email "${GIT_COMMITTER_EMAIL:-"$(git config user.email)"}"
	git config --global user.signingkey "${GPG_KEY_ID:-$GIT_COMMITTER_EMAIL}"
	git config --global commit.gpgsign "true"
	git config --global tag.gpgsign "true"
}

function __gpg_vscode()
{
	local VSCODE SETTINGS_JSON
	VSCODE="/workspace/.vscode-remote"
	[ -d "$VSCODE" ] || mkdir -p "$VSCODE"
	SETTINGS_JSON="$VSCODE/settings.json"
	[ -f "$SETTINGS_JSON" ] || echo "{}" > "$SETTINGS_JSON"
	if [[ "$(get_json "$SETTINGS_JSON" git.enableCommitSigning)" != 'true' ]]; then
		set_json "$SETTINGS_JSON" 'git.enableCommitSigning' 'true'
	fi
}

function __gpg_setup()
{
	local PINENTRY_CONF GPG_CONF
	PINENTRY_CONF='pinentry-mode loopback'
	GPG_CONF="$HOME/.gnupg/gpg.conf"
	# unset -v GPG_CONFIGURED
	touch "$GPG_CONF"
	if ! grep -q "$PINENTRY_CONF" "$GPG_CONF" &> /dev/null; then
		echo "$PINENTRY_CONF" >> "$GPG_CONF"
	fi

	sudo chmod 700 ~/.gnupg &> /dev/null
	gpg --batch --import <(echo "${GPG_KEY-}" | base64 -d) &> /dev/null

	(
		__gpg_gitconfig &> /dev/null
		__gpg_vscode
		__gpg_reload
	) &> /dev/null && export GPG_CONFIGURED=1
}

function __gpg_reload()
{
	gpgconf --kill gpg-agent
	gpg-connect-agent reloadagent /bye &> /dev/null
}

function __gpg_count_keys()
{
  local key_id=""
  if [ -n "$1" ]; then
    key_id="$1"; shift;
    # shellcheck disable=SC2005
    echo "$(gpg -K "${key_id:+$key_id}" 2>/dev/null | grep sec --count 2>/dev/null)" | tr -d $'\n'
  else
    # shellcheck disable=SC2005
    echo "$(gpg -K | grep sec --count 2>/dev/null)" | tr -d $'\n'
  fi
}

# super hacky "fix" (bandaid on a bullethole tbh) for gpg failure to initialize
function gpg_init()
{
	export GPG_TTY=$(tty)
	[ -z "${GPG_CONFIGURED:+x}" ] && __gpg_setup 2> /dev/null
	__gpg_reload 2> /dev/null
	(echo "" | gpg --clear-sign --pinentry-mode loopback > /dev/null) \
		&& printf '\033[1;32m %s\033[0m\n' '🟢 🔐 GPG unlocked and ready to sign!' \
		|| printf '\033[1;31m %s\033[0m\n' '🛑 🔒 GPG failed to unlock! Bad passphrase?'
}

# check if our GPG key and key id have been set in the environment
if [[ -n "${GPG_KEY:+x}" || -n "${GPG_PRIVATE_KEY:+x}" ]] && [ -n "$GPG_KEY_ID" ]; then
    # check if the secret key has been configured with gpg
    if [ "$(__gpg_count_keys "${GPG_KEY_ID-}")" -gt 0 ]; then
      __gpg_setup 2> /dev/null
    fi
fi
