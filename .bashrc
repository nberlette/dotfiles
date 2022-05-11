#!/usr/bin/env bash
# -*- coding: utf-8 -*-

## ------------------------------------------------------------------------ ##
##  .bashrc                                  Nicholas Berlette, 2022-05-11  ##
## ------------------------------------------------------------------------ ##
##  https://github.com/nberlette/dotfiles/blob/main/.bashrc                 ##
## ------------------------------------------------------------------------ ##

if [ -n "$BASH_VERSION" ]; then
  if [ -f "$HOME/.bash_profile" ]; then
    . "$HOME/.bash_profile"
  fi
fi
