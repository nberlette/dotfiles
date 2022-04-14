#!/usr/bin/env bash
shell="$(which bash)"
export SHELL="$shell"
export DOTFILES_PREFIX="${DOTFILES_PREFIX:-"$HOME/.dotfiles"}"

[ -r ~/.path ] && source ~/.path;

# import all vars from .env + .extra into current environment
srx ~/.{env,extra}

# include our core bash environment
src ~/.{exports,functions,bash_aliases,profile}

# ruby version manager
src ~/.rvm/scripts/rvm

# TODO: move this to an install script so it's always ready on runtime
function get_var() {
  eval 'printf "%s\n" "${'"$1"'}"'
}

function set_var() {
  eval "$1=\"\$2\""
}

function dedupe_path() {
  local pathvar_name pathvar_value deduped_path
  pathvar_name="${1:-PATH}"
  pathvar_value="$(get_var "$pathvar_name")"
  deduped_path="$(perl -e 'print join(":",grep { not $seen{$_}++ } split(/:/, $ARGV[0]))' "$pathvar_value")"
  set_var "$pathvar_name" "$deduped_path"
}

function get_json() {
  local path file
  file="${1:-"/workspace/.vscode-remote/settings.json"}"
  path="${2:-git.enableCommitSigning}"
  jq '.["'$path'"]' "$file" 2>/dev/null || return $?
}

function set_json() {
  local path value file
  file="${1:-"/workspace/.vscode-remote/settings.json"}"
  path="${2:-git.enableCommitSigning}"
  value="${3:-true}"
  jq '.["'$path'"]=$value | .' "$file" 2>/dev/null || return $?
}

function __gpg_gitconfig () {
  [ -n "${GPG_KEY_ID-}" ] && git config --global user.signingkey "${GPG_KEY_ID-}"
  git config --global commit.gpgsign "true"
  git config --global tag.gpgsign "true"
}

function __gpg_vscode () {
  local VSCODE SETTINGS_JSON
  VSCODE="/workspace/.vscode-remote"
  [ -d "$VSCODE" ] || mkdir -p "$VSCODE"
  SETTINGS_JSON="$VSCODE/settings.json"
  [ -f "$SETTINGS_JSON" ] || echo "{}" >"$SETTINGS_JSON"
  if [[ "$(get_json "$SETTINGS_JSON" git.enableCommitSigning)" != 'true' ]]; then
    set_json "$SETTINGS_JSON" 'git.enableCommitSigning' 'true'
  fi
}

function __gpg_unlock () {
  local PINENTRY_CONF GPG_CONF
  PINENTRY_CONF='pinentry-mode loopback'
  GPG_CONF="$HOME/.gnupg/gpg.conf"
  unset -v GPG_CONFIGURED
  touch "$GPG_CONF"
  if ! grep -q "$PINENTRY_CONF" "$GPG_CONF" >/dev/null 2>&1; then
    echo "$PINENTRY_CONF" >>"$GPG_CONF"
  fi
  gpg --batch --import <(echo "${GPG_KEY-}" | base64 -d) >&/dev/null

  __gpg_gitconfig
  __gpg_vscode

  gpgconf --kill gpg-agent
  gpg-connect-agent reloadagent /bye >&/dev/null
  export GPG_CONFIGURED=1
}

export GPG_TTY=$(tty)
[ -n "${GPG_KEY-}" ] && __gpg_unlock 2>/dev/null

# starship shell prompt with fallback
__prompt () {
  if ! which starship >&/dev/null; then
    # its horribly hacky, but I'm short on time and it works for now. (I hope)
    brew install starship --quiet && __prompt 2>/dev/null;
  fi

  eval "$(starship completions bash 2>/dev/null)"
  eval "$(starship init bash 2>/dev/null)"
};
# instantiate and cleanup afterwards
__prompt && unset -f __prompt || {
  PROMPT_COMMAND+=' __git_ps1 "[\$?] '"${GIT_PS1_PREFIX-}"'" "'"${GIT_PS1_SUFFIX-}"'" "'"${GIT_PS1_FORMAT:- %s }"'"'
  export PROMPT_COMMAND
};
