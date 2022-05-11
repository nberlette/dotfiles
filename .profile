#!/usr/bin/env bash
# -*- coding: utf-8 -*-

## ------------------------------------------------------------------------ ##
##  .profile                                 Nicholas Berlette, 2022-05-11  ##
## ------------------------------------------------------------------------ ##
##  https://github.com/nberlette/dotfiles/blob/main/.profile                ##
## ------------------------------------------------------------------------ ##

if [ -n "$BASH_VERSION" ]; then
  if [ -f "$HOME/.bash_profile" ]; then
    . "$HOME/.bash_profile"
  fi
fi
