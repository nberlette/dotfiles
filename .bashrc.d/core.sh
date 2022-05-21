#!/usr/bin/env bash
# -*- coding: utf-8 -*-

## ------------------------------------------------------------------------ ##
##  .bashrc.d/core.sh                        Nicholas Berlette, 2022-05-21  ##
## ------------------------------------------------------------------------ ##
##  https://github.com/nberlette/dotfiles/blob/main/.bashrc.d/core.sh       ##
## ------------------------------------------------------------------------ ##

# if [ -z "${DOTFILES_CORE_INITIALIZED:+x}" ]; then

  # src - source multiple files or entire folders recursively, with sanity checks.
  function src() {
    local file child
    for file in "$@"; do
      if [ -r "$file" ] && [ -f "$file" ]; then
        # shellcheck source=/dev/null
        source "$file"
      elif [ -d "$file" ]; then
        for child in "$file"/**; do
          src "$child"
        done
      fi
    done
  }

  # srx: executes src function for all arguments, with the -a flag enabled.
  # basically a recursive version of dotenv. enables sourcing a whole folder,
  # and exporting all its files' variables into the global environment.
  # use with caution.
  function srx() {
    local file
    for file in "$@"; do
      if [ -r "$file" ]; then
        set -a
        src "$file"
        set +a
      fi
    done
  }

  # curdir :]
  if ! type curdir &>/dev/null; then
    # determine actual script location
    function curdir() {
      realpath -L -P -e "${1:-"${BASH_SOURCE[0]}"}" 2>/dev/null
    }
  fi

  # dedupe_array_str: remove duplicate entries from a list string (or array string)
  # this is the logic used to cleanup the PATH variable of all duplicates while
  # maintaining original insertion order ;)
  # Usage:
  #   $ dedupe_array_str ["$DELIMITER"] "$VARIABLE"
  # Example used for $PATH:
  #   $ dedupe_array_str ":" "PATH" # : is for splitting string into an array
  function dedupe_array_str () {
    local OLD NEW _IFS="$IFS" SEP=":"
    [ -n "$1" ] && [ ${#1} -eq 1 ] && { SEP="${1:-":"}"; shift; }
    IFS="$SEP"; OLD="${*}"; IFS="$_IFS";
    NEW="$(perl -e 'print join("'"${SEP-}"'",grep { not $seen{$_}++ } split(/'"${SEP-}"'/, $ARGV[0]))' "$OLD")"
    # now cleanup any lingering delimiters
    NEW="${NEW#"$SEP"}" # remove leading separators
    NEW="${NEW%"$SEP"}" # remove trailing separators
    echo -n "$NEW"
  }

  ########
  ## functions used in .path to amend the $PATH variable
  ########
  function get_var() {
    eval 'printf "%s\n" "${'"$1"'}"'
  }

  function set_var() {
    eval "$1=\"\$2\""
  }

  function dedupe_path() {
    local pathvar_value deduped_path print_val set_val
    # print by default for backwards compatibility
    print_val=1

    while (($# > 0)); do
      if [[ "$1" =~ ^([-]{1,2}p(rint)?)$ ]]; then
        print_val=1; shift; continue
      fi
      # how bout that for nested groups bruh
      if [[ "$1" =~ ^([-]{1,2}s(et([-]?val(ue)?)?)?)$ ]]; then
        set_val=1; shift; continue
      fi
    do
    pathvar_value="${1:-$PATH}"
    # deduped_path="$(perl -e 'print join(":",grep { not $seen{$_}++ } split(/:/, $ARGV[0]))' "$pathvar_value")"
    deduped_path="$(dedupe_array_str ":" "${pathvar_value-}")"

    [ -n "$set_val" ] \
      && set_var "$pathvar_name" "$deduped_path";

    [ -n "$print_val" ] \
      && echo -n "$deduped_path";
  }



  # installs all arguments as global packages
  function global_add() {
    local pkg pkgs=("$@") agent=npm command="i -g"
    if which pnpm &>/dev/null; then
      agent=pnpm; command="add -g";
    elif which yarn &>/dev/null; then
      agent=yarn; command="global add";
    else
      agent=npm; command="i -g";
    fi
    $agent $command "${pkgs[@]}" &>/dev/null && {
      echo "Installed with $agent:"
      for pkg in "${pkgs[@]}"; do
        echo -e "\\033[1;32m ✓ $pkg \\033[0m"
        # || echo -e "\\033[1;48;2;230;30;30m 𐄂 ${pkg-}\\033[0m";
      done
    }
  }

  # export DOTFILES_CORE_INITIALIZED=1
# fi
