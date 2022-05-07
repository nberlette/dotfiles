#!/usr/bin/env bash
# -*- coding: utf-8 -*-

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

# curdir: determine the actual path of the current script
function curdir() {
  local DIR NOT_CI
  NOT_CI="$(test -z "$CI" && echo -n 1)"
  # strategy 1: readlink (-n|-f) of current script's dirname
  DIR="$(readlink ${CI:+"-n"} ${NOT_CI:+"-f"} "$(dirname -- "${BASH_SOURCE}")" 2>/dev/null)"

  # strategy 2: cd to the dirname of current script and run pwd()
  [ -z "$DIR" ] && DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

  # print the result of whichever strategy worked
  echo -n "$DIR"
}

# dedupe: remove duplicate entries from a list, used to cleanup the PATH variable
function dedupe() {
	local OLD NEW _IFS="$IFS" SEP=":"
  [ -n "$1" ] && [ ${#1} -eq 1 ] && { SEP="${1:-":"}"; shift; }
  IFS="$SEP"; OLD="${*}"; IFS="$_IFS";
  NEW="$(perl -e 'print join("'"${SEP-}"'",grep { not $seen{$_}++ } split(/'"${SEP-}"'/, $ARGV[0]))' "$OLD")"
  echo -n "$NEW"
}

# clean_path: remove duplicate/empty entries from the PATH variable
function clean_path () {
  local _EXPORT=0 _IFS="$IFS" _PATH="$(dedupe : "$PATH")"
  [ "$1" = "-e" ] && { _EXPORT=1; shift; }

  _PATH="${_PATH//"::"/}" # remove any double-colons from missing path variables
  _PATH="${_PATH#:}" # remove any trailing colon
  _PATH="${_PATH%:}" # remove any preceding colon

  # depending on if -e was passed, export the result or just print it
  [ $_EXPORT -eq 1 ] && { PATH="$_PATH"; export PATH; } || echo -n "$_PATH"
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
