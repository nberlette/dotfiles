#!/usr/bin/env bash
# -*- coding: utf-8 -*-

## ------------------------------------------------------------------------ ##
## .dotfiles                                                     2022-05-18 ##
## ------------------------------------------------------------------------ ##
##      https://github.com/nberlette/dotfiles/blob/main/.bash_profile       ##
## ------------------------------------------------------------------------ ##
##              MIT © Nicholas Berlette <nick@berlette.com>                 ##
## ------------------------------------------------------------------------ ##

shell="$(which bash)"
export SHELL="$shell"

if ! type curdir &>/dev/null; then
  # determine actual script location
  function curdir() {
    printf "%s" "$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
  }
fi

# source the .path file to make sure all programs and functions are accessible
# this also sources our core.sh file. and if it cant be found, it fails. HARD.
[ -r ~/.path ] \
  && source ~/.path 2>/dev/null \
    || source "${DOTFILES_PREFIX:-"$HOME/.dotfiles"}/.path" 2>/dev/null \
      || exit $? ;

# import all vars from .env + .extra into current environment
srx ~/.{env,extra} "${PWD-}"/.{env,env.d}

# include our core bash environment
src ~/.{exports,functions,bash_aliases}

# ruby version manager, cargo (rust), nix
src ~/.rvm/scripts/rvm ~/.cargo/env ~/.nix-profile/etc/profile.d/nix.sh

# bash completion
src "$HOMEBREW_PREFIX/etc/bash_completion.d" 2> /dev/null

which lesspipe &>/dev/null && eval "$(SHELL="$shell" lesspipe)";

# color codes for ls, grep, etc.
if which dircolors &>/dev/null; then
  [ -r ~/.dircolors ] && eval "$(dircolors -b ~/.dircolors 2>/dev/null)" || eval "$(dircolors -b)"
fi

# clean up $PATH
if type dedupe_path &>/dev/null; then
  dedupe_path 2>/dev/null
fi

# make sure our gitconfig is up to date

# user.name
if [[ -z "$(git config --global user.name)" && -n "$GIT_COMMITTER_NAME" ]]; then
  git config --global user.name "$GIT_COMMITTER_NAME";
fi

# user.email
if [[ -z "$(git config --global user.email)" && -n "$GIT_COMMITTER_NAME" ]]; then
  git config --global user.email "$GIT_COMMITTER_EMAIL";
fi

# user.signingkey
if [[ -z "$(git config --global user.signingkey)" && -n "$GPG_KEY_ID" ]]; then
  git config --global user.signingkey "${GPG_KEY_ID:-$GIT_COMMITTER_EMAIL}"
fi

# starship shell prompt with fallback
eval "$(starship init bash)"
