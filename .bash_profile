#!/usr/bin/env bash
shell="$(which bash)"
export SHELL="$shell"
export DOTFILES_PREFIX="${DOTFILES_PREFIX:-"$HOME/.dotfiles"}"

# determine actual script location
function curdir() {
  printf "%s" "$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
}

[ -r ~/.path ] && source ~/.path

# include .bashrc.d/*
src ~/.bashrc.d

# import all vars from .env + .extra into current environment
srx ~/.{env,extra}

# include our core bash environment
src ~/.{exports,functions,bash_aliases}

# ruby version manager, cargo (rust), nix
src ~/.rvm/scripts/rvm ~/.cargo/env ~/.nix-profile/etc/profile.d/nix.sh

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

# clean up the path
dedupe_path 2>/dev/null

# make sure our gitconfig is up to date
if [[ -z "$(git config --global user.name)" && -n "$GIT_COMMITTER_NAME" ]]; then
  git config --global user.name "$GIT_COMMITTER_NAME";
fi
if [[ -z "$(git config --global user.email)" && -n "$GIT_COMMITTER_NAME" ]]; then
  git config --global user.email "$GIT_COMMITTER_EMAIL";
fi
if [[ -z "$(git config --global user.signingkey)" && -n "$GPG_KEY_ID" ]]; then
  git config --global user.signingkey "${GPG_KEY_ID:-$GIT_COMMITTER_EMAIL}"
fi

# starship shell prompt with fallback
eval "$(starship init bash)"
