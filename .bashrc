#!/usr/bin/env bash
# -*- coding: utf-8 -*-

## ------------------------------------------------------------------------ ##
## .bashrc                                    Nicholas Berlette, 2022-06-01 ##
## ------------------------------------------------------------------------ ##
##         https://github.com/nberlette/dotfiles/blob/main/.bashrc          ##
## ------------------------------------------------------------------------ ##
##              MIT © Nicholas Berlette <nick@berlette.com>                 ##
## ------------------------------------------------------------------------ ##

shell="$(command -v bash)"
export SHELL="$shell"

# if [ -z "${DOTFILES_INITIALIZED:+x}" ]; then
# source the .path file to make sure all programs and functions are accessible
# this also sources our core.sh file. and if it cant be found, it fails. HARD.
if [ -r ~/.path ]; then {
  # shellcheck source=/dev/null
  source ~/.path 2>/dev/null || source "${DOTFILES_PREFIX:-"$HOME/.dotfiles"}/.path" 2>/dev/null
} || exit $?; fi

# import all vars from .env + .extra into current environment
srx ~/.{env,extra} "${PWD-}"/.{env,env.d}

# include our core bash environment
src ~/.{exports,functions,bash_aliases}

# ruby version manager, cargo (rust), nix
src ~/.rvm/scripts/rvm ~/.cargo/env ~/.nix-profile/etc/profile.d/nix.sh

# bash completion
src "$HOMEBREW_PREFIX/etc/bash_completion.d" 2>/dev/null

which lesspipe &>/dev/null && eval "$(SHELL="$shell" lesspipe)"

# color codes for ls, grep, etc.
if which dircolors &>/dev/null; then
  [ -r ~/.dircolors ] && eval "$(dircolors -b ~/.dircolors 2>/dev/null)" || eval "$(dircolors -b)"
fi

export PATH="${HOMEBREW_PREFIX:+"$HOMEBREW_PREFIX/bin:"}$PATH"

# clean up $PATH
if type dedupe_path &>/dev/null; then
  export PATH="$(dedupe_path)"
fi

# make sure our gitconfig is up to date
# user.name, user.email, user.signingkey
if [ -z "$(git config --global user.name)" ] || [ -z "$(git config --global user.email)" ]; then
  if [ -n "$GIT_COMMITTER_NAME" ] || [ -n "$GIT_AUTHOR_NAME" ]; then
    git config --global user.name "${GIT_COMMITTER_NAME:-"$GIT_AUTHOR_NAME"}"
  fi
  if [ -n "$GIT_COMMITTER_EMAIL" ] || [ -n "$GIT_AUTHOR_EMAIL" ]; then
    git config --global user.email "${GIT_COMMITTER_EMAIL:-"$GIT_AUTHOR_EMAIL"}"
  fi
  if [ -z "$(git config --global user.signingkey)" ]; then
    git config --global user.signingkey "${GPG_KEY_ID:-"$GIT_COMMITTER_EMAIL"}"
  fi
fi

# super janky way to skirt around gitpod's 120 second timeout on dotfiles installs
# I'll get around to a better solution.... someday
if [ -e ~/.DOTFILES_BREW_BUNDLE ]; then
  rm -f ~/.DOTFILES_BREW_BUNDLE &>/dev/null
  if [[ $- == *i* ]]; then
    read -r -n 1 -i y -t 60 -p $'\n\033[0;1;5;33m ☢︎ \033[0;1;31m WARNING!\033[0m\n\n\033[2;3;91mThe dotfiles installer created a .Brewfile of recommended packages to install.\nThe downside, however, is this installation could take 5 minutes to complete.\033[0;3;31m\033[0m\n\n\033[0;1;4;33mAccept and continue?\033[0;2m (respond within 60s or \033[1m"Yes"\033[0;2m is assumed)\n\n\033[0;2m(\033[0;1;4;32mY\033[0;1;2;32mes\033[0;2m / \033[0;1;4;31mN\033[0;1;2;31mo\033[0;2m)\033[0m ... '
    # if the user says yes, or force, run the install
    if (($? > 128)) || [[ $REPLY == [Yy]* ]]; then
      echo ''
      DOTFILES_SKIP_HOME=1 DOTFILES_SKIP_NODE=1 DOTFILES_BREW_BUNDLE=1 ~/.dotfiles/install.sh
    else
      echo -e '\n\n\033[1;31mSkipped Brewfile installation.\033[0m\n'
    fi # $REPLY
  fi
fi

eval "$(starship init bash)"

# define our variable to indicate this file has already been executed
# export DOTFILES_INITIALIZED=1
# fi
