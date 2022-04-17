#!/usr/bin/env bash
shell="$(which bash)"
export SHELL="$shell"
export DOTFILES_PREFIX="${DOTFILES_PREFIX:-"$HOME/.dotfiles"}"

[ -r ~/.path ] && source ~/.path;

# import all vars from .env + .extra into current environment
srx ~/.{env,extra}

# include our core bash environment
src ~/.{exports,functions,bash_aliases}

# ruby version manager, cargo (rust), nix
src ~/.rvm/scripts/rvm ~/.cargo/env ~/.nix-profile/etc/profile.d/nix.sh

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
  # quotemageddon
  jq '.["'"$path"'"]' "$file" 2>/dev/null || return $?
}

function set_json() {
  local path value file
  file="${1:-"/workspace/.vscode-remote/settings.json"}"
  path="${2:-git.enableCommitSigning}"
  value="${3:-true}"
  # holy freakin quotes batman
  jq '.["'"$path"'"]=$value | .' "$file" 2>/dev/null || return $?
}

function __gpg_gitconfig () {
  [ -z "$(git config --global user.name)" ] && {
    git config --global user.name "$GIT_COMMITTER_NAME";
    git config --global user.email "$GIT_COMMITTER_EMAIL";
  }
  git config --global user.signingkey "${GPG_KEY_ID:-$GIT_COMMITTER_EMAIL}";
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

function gpgsetup () {
  local PINENTRY_CONF GPG_CONF
  PINENTRY_CONF='pinentry-mode loopback'
  GPG_CONF="$HOME/.gnupg/gpg.conf"
  unset -v GPG_CONFIGURED
  touch "$GPG_CONF"
  if ! grep -q "$PINENTRY_CONF" "$GPG_CONF" >/dev/null 2>&1; then
    echo "$PINENTRY_CONF" >>"$GPG_CONF"
  fi

  gpg --batch --import <(echo "${GPG_KEY-}" | base64 -d) >&/dev/null

  __gpg_gitconfig 2>/dev/null
  __gpg_vscode 2>/dev/null

  gpgconf --kill gpg-agent
  gpg-connect-agent reloadagent /bye &>/dev/null
  export GPG_CONFIGURED=1
}

# super hacky "fix" (bandaid on a bullethole tbh) for gpg failure to initialize
function gpg_init() {
  gpgsetup 2>/dev/null
  (echo "" | gpg --clear-sign --pinentry-mode loopback >/dev/null)\
    && printf '\033[1;32m %s\033[0m\n' '🔓 unlocked GPG key and ready to sign!' \
    || printf '\033[1;31m %s\033[0m\n' '🔒 could not unlock GPG key. bad passphrase?';
}

export GPG_TTY=$(tty)
[ -n "${GPG_KEY-}" ] && gpgsetup 2>/dev/null

# starship shell prompt with fallback
eval "$(starship init bash)"
