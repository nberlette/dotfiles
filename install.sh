#!/usr/bin/env bash
# -*- coding: utf-8 -*-

## ------------------------------------------------------------------------ ##
##  install.sh                               Nicholas Berlette, 2022-05-31  ##
## ------------------------------------------------------------------------ ##
##        https://github.com/nberlette/dotfiles/blob/main/install.sh        ##
## ------------------------------------------------------------------------ ##
##              MIT © Nicholas Berlette <nick@berlette.com>                 ##
## ------------------------------------------------------------------------ ##

# ask for password right away
sudo -v

# verbosity flag
# default level is --quiet , in CI/CD --verbose
verbosity="--quiet"

# always ebable verbose logging if in CI/CD
[ -n "${CI:+x}" ] && verbosity="--verbose"

# current step number, total step count
STEP_NUM=1
STEP_TOTAL=3

# ensure $TERM is set in CI/CD (gh-actions)
[ -z "${TERM:+x}" ] && export TERM="${TERM:-"xterm-color"}"

# check for ostype
if ! hash ostype &> /dev/null; then
  function ostype() {
    uname -s | tr '[:upper:]' '[:lower:]' 2> /dev/null
  }
fi

# check for is_interactive
if ! hash is_interactive &> /dev/null; then
  function is_interactive() {
    # if we're in CI/CD, return code 1 immediately
    if [ -n "$CI" ]; then return 1; fi

    # no? okay, lets check for tty based on stdin, stdout, stderr
    if [ -t 0 ] && [ -t 1 ] && [ -t 2 ]; then return 0; fi

    # no? then we will check shellargs for -i as a last resort
    case $- in *i*) return 0 ;; esac

    # ..... no?! you're still here? throw an error >_>
    return 2
  }
fi

# check for curdir
if ! hash curdir &> /dev/null; then
  # determine actual script location
  # shellcheck disable=SC2120
  function curdir() {
    dirname -- "$(realpath -Lmq "${1:-"${BASH_SOURCE[0]}"}" 2> /dev/null)"
  }
fi

# $OSTYPE variable (linux-gnu, darwin, etc)
[ -z "${OSTYPE:+x}" ] && OSTYPE=$(ostype)

# $IS_DARWIN=1 if on a Mac
[[ $OSTYPE == [Dd]arwin* ]] && IS_DARWIN=1 || IS_DARWIN="";

# IS_INTERACTIVE=1 if interactive, 0 otherwise (duh)
# (like in CI/CD, or Codespaces/Gitpod autoinstall during prebuilds)
declare -g -r -x IS_INTERACTIVE="$(is_interactive 2>&1 && echo -n 1)"

export TZ='America/Los_Angeles'
declare -g -r -x DOTFILES_PREFIX="${DOTFILES_PREFIX:-"$HOME/.dotfiles"}"
declare -g -r -x DOTFILES_LOGPATH="$DOTFILES_PREFIX/_installs/$(date +%F)-$(date +%s)"
declare -g -r -x DOTFILES_LOG="${DOTFILES_LOGPATH-}/install.log"
declare -g -r -x DOTFILES_BACKUP_PATH="${DOTFILES_LOGPATH}/.backup"
[ -d "$DOTFILES_LOGPATH" ] || mkdir -p "$DOTFILES_LOGPATH" &> /dev/null
[ -d "$DOTFILES_BACKUP_PATH" ] || mkdir -p "$DOTFILES_BACKUP_PATH" &> /dev/null
command touch "$DOTFILES_LOG" &> /dev/null

DOTFILES_CORE="$(curdir 2> /dev/null || echo -n "$DOTFILES_PREFIX")/.bashrc.d/core.sh"

# shellcheck source=/dev/null
[ -r "$DOTFILES_CORE" ] && . "$DOTFILES_CORE"

cd "$(curdir)" 2> /dev/null || exit 1


# check for global_add
if ! hash global_add &> /dev/null; then
  # installs all arguments as global packages
  function global_add() {
    local pkg pkgs=("$@") agent=npm command="i -g"
    if command -v yarn &> /dev/null; then
      agent="$(command -v yarn)"
      command="global add"
    else
      agent="$(command -v pnpm 2> /dev/null || command -v npm 2> /dev/null)"
      command="i -g"
    fi
    $agent "$command" "${pkgs[@]}" &> /dev/null && {
      echo "Installed with $agent:"
      for pkg in "${pkgs[@]}"; do
        echo -e "\\033[1;32m ✓ $pkg \\033[0m"
        # || echo -e "\\033[1;48;2;230;30;30m 𐄂 ${pkg-}\\033[0m";
      done
    }
  }

fi

function print_banner() {
  local message divider i
  case "${1-}" in
    step)
      printf '\033[1;2;4m(%d/%d)\033[0m \033[1m%s\033[0m\n\n' "$STEP_NUM" "$STEP_TOTAL" "${*:2}"
      ;;
    *)
      divider="" divider_char="-"
      if [ "${#1}" = "1" ] && [ -n "$2" ]; then
        divider_char="${1:-"-"}"
        message="${*:2}"
      else
        message="${*:-"Beginning dotfiles installation"}"
      fi
      for ((i = 0; i < ${COLUMNS:-100}; i++)); do
        divider+="${divider_char:-"="}"
      done
      printf '\033[1m %s \033[0m\n\033[2m%s\033[0m\n' "${message-}" "${divider-}"
      ;;
  esac
}

# shellcheck disable=SC2120
function print_step_complete() {
  if (($# > 0)); then
    printf '\n\033[1;48;2;40;60;66;38;2;240;240;240m %s \033[0;2;3m %s\n\n' "${1-}" "${*:2}"
  else
    # display the completed step number and total number of steps
    echo -e '\n\033[1;32m ✓ \033[0;32;3mCompleted step '"$STEP_NUM"' of '"$STEP_TOTAL"'.\033[0m\n\n'
    # increment step number by 1
    ((STEP_NUM++))
  fi
}

# install homebrew (if needed) and some commonly-used global packages. the bare minimum.
function setup_brew() {
  local BREWFILE

  print_banner step $'Installing/upgrading \033[1;4;35mhomebrew\033[0;1m and required formulae...'
  {
    # install homebrew if not already installed
    if ! command -v brew &> /dev/null; then
      curl -fsSL https://raw.github.com/Homebrew/install/HEAD/install.sh | bash -
    fi
    # execute now just to be sure its available for us immediately
    eval "$(brew shellenv 2> /dev/null)"
  } | tee -i -a "$DOTFILES_LOG" 2>&1

  # set our brewfile location
  BREWFILE="$(realpath -eLq "${DOTFILES_PREFIX-}/.Brewfile" 2> /dev/null || echo -n "$DOTFILES_PREFIX/.Brewfile")"

  # don't install when we're in a noninteractive environment (read: gitpod dotfiles setup task)
  # otherwise this usually takes > 120s and fails hard thanks to gitpod's rather unreasonable time limit.
  # also, skip this step if we're in CI/CD (github actions), because... money reasons.
  if [ -z "${CI:+x}" ] && [ -n "${IS_INTERACTIVE+x}" ]; then

    # for developing jekyll sites (and other things for github pages, etc)
    if command -v gem &> /dev/null; then
      gem install jekyll bundler >> "$DOTFILES_LOG" 2>&1
    fi

    # for macOS
    if [ "$IS_DARWIN" = 1 ]; then
      BREWFILE="$(realpath -eLq "${DOTFILES_PREFIX-}/.osx/.Brewfile" 2> /dev/null || echo -n "$DOTFILES_PREFIX/.osx/.Brewfile")"
      {
        command -v rvm &> /dev/null || curl -fsSL https://get.rvm.io | bash -s stable --rails
        export SHELL="${HOMEBREW_PREFIX:-}/bin/bash"

      } | tee -i -a "$DOTFILES_LOG" 2>&1
    fi
  fi

  if [ -r "$BREWFILE" ]; then
    # make sure its executable...
    [ -x "$BREWFILE" ] || chmod +x "$BREWFILE" 2>/dev/null;
    # and then execute it
    brew bundle install "${verbosity-}" --overwrite --display-times --file="${BREWFILE:-"$HOME/.Brewfile"}" --no-lock | tee -i -a "$DOTFILES_LOG" 2>&1;
  fi

  # shellcheck disable=SC2119
  print_step_complete
}

# installs PNPM and Node.js (if needed) and some minimal global packages
function setup_node() {
  # shellcheck disable=SC2120
  local node_v
  node_v="${1:-lts}"

  local -a global_util_packages=(zx fsxx @brlt/n @brlt/prettier prettier @brlt/eslint-config eslint @brlt/utils degit)
  local -a global_cli_packages=(dotenv-vault vercel wrangler@latest miniflare@latest @railway/cli netlify-cli)

  print_banner step "$(printf 'Installing/upgrading \033[1;4;31mPNPM\033[0;1m and \033[4;32mNode\033[0;1;2m v%s\033[0m' "${node_v:-LTS}")"

  {
    # install pnpm if not already installed
    if ! command -v pnpm &> /dev/null; then
      curl -fsSL https://get.pnpm.io/install.sh | bash -
    fi
    # ensure we have node.js installed
    if ! command -v node &> /dev/null || ! node -v &> /dev/null; then
      {
        pnpm env use -g "${node_v:-lts}" 2> /dev/null || pnpm env use -g 16
      } && pnpm setup 2> /dev/null
    fi
  } | tee -i -a "$DOTFILES_LOG" 2>&1

  global_add "${global_util_packages[@]}"

  if [ -z "${IS_INTERACTIVE+x}" ]; then
    global_add "${global_cli_packages[@]}"
  else # interactive
    read -r -n 1 -i y -t 30 -p $'\n\033[0;1;5;33m⚠  \033[0m\033[1;33mInstall CLIs for Vercel/Railway/Netlify/Cloudflare?\033[0m\n\n\033[0;2m(\033[0;1;4;32mY\033[0;1;2;32mes\033[0;2m / \033[0;1;4;31mN\033[0;1;2;31mo\033[0;2m)\033[0m ... '
    local prompt_status=$?
    echo ''

    if [[ $REPLY == [Yy]* ]] || ((prompt_status > 128)); then
      global_add "${global_cli_packages[@]-}"
    fi

    STEP_NUM=$((STEP_NUM+1))
  fi

  # shellcheck disable=SC2119
  print_step_complete
}

# setup our new homedir with symlinks to all the dotfiles
function setup_home() {
  local rsyncfiles rsyncexclude rsyncinclude git_file
  local -a rsyncargs=()

  # backup (preserving homedir structure), e.g. /home/gitpod/.dotfiles/.backup/home/gitpod/.bashrc~
  [ -d "${DOTFILES_BACKUP_PATH-}" ] || mkdir -p "${DOTFILES_BACKUP_PATH-}" &> /dev/null

  # set the default locations for .rsyncfiles and .rsyncexclude files
  rsyncfiles="${DOTFILES_PREFIX-}/.rsyncfiles"
  rsyncexclude="${DOTFILES_PREFIX-}/.rsyncexclude"
  rsyncinclude="${DOTFILES_PREFIX-}/.rsyncinclude"

  # set the common arguments used by all of our rsync invocations
  rsyncargs+=(-avh --recursive --perms --times --checksum --itemize-changes --human-readable --progress --log-file="${DOTFILES_LOG}" --backup --backup-dir="${DOTFILES_BACKUP_PATH-}")

  # .gitignore and .gitconfig are special!
  # we have to rename them to avoid issues with git applying them to the repository
  for git_file in "gitignore" "gitconfig"; do
    mv -f -v ~/."$git_file" "${DOTFILES_BACKUP_PATH-}" | tee -i -a "$DOTFILES_LOG" 2>&1
    rsync "${rsyncargs[@]}" "$git_file" ~/."$git_file";
  done


  # exclude files matching glob patterns in the file .dotfiles/.rsyncexclude
  [ -n "${rsyncexclude-}" ] && [ -r "${rsyncexclude-}" ] &&
    rsyncargs+=(--exclude-from="${rsyncexclude-}");

  # include files with glob patterns in the file .dotfiles/.rsyncinclude
  [ -n "${rsyncinclude-}" ] && [ -r "${rsyncinclude-}" ] &&
    rsyncargs+=(--include-from="${rsyncinclude-}");

  # explicitly list files to copy in .dotfiles/.rsyncfiles
  [ -n "${rsyncfiles-}" ] && [ -r "${rsyncfiles-}" ] &&
    rsyncargs+=(--files-from="${rsyncfiles-}");

  # now do the damn thang!
  rsync "${rsyncargs[@]}" "$(curdir 2>/dev/null || echo -n "$DOTFILES_PREFIX")" "$HOME";

  return 0
}

# runs all the other scripts and cleans up after itself. geronimo!
function main() {
  # make sure we are in the root ~/.dotfiles directory
  cd "${DOTFILES_PREFIX-}" || return ;

  print_banner "Spooling up the dotfiles installer..."
  printf ' \033[1;4m%s\033[0m: %s \n\n' 'Working Dir' "$(curdir)"

  # if we are in a github codespaces environment, skip homebrew setup for now.
  # currently the homebrew installer breaks due to a git syntax error in their code. works fine in gitpod though. 🤔
  if [ -n "${CODESPACES+x}" ]; then
    STEP_TOTAL=2 # adjust step total since we're skipping homebrew
    curl -sS https://starship.rs/install.sh | sh -
  else
    STEP_TOTAL=3
    setup_brew # for everything else
  fi

  # setup pnpm + node.js and install some global packages I frequently use
  # pin node.js to 16.14.2 to prevent breaking errors
  setup_node "16.15.0";

  # syncing the home directory
  print_banner step $'Syncing \033[1;4;33mdotfiles\033[0;1m to \033[1;3;4;36m'"$HOME"

  # if we are in interactive mode (not in CI/CD), ask the user if they want to proceed
  if is_interactive 2>/dev/null || [ -n "${IS_INTERACTIVE+x}" ]; then
    read -r -n 1 -i y -t 30 -p $'\n\033[0;1;5;33m⚠  \033[0;1;31m DANGER \033[0m ·  \033[3;31mContinuing with install will overwrite existing files in \033[3;4m'"$HOME"$'\033[0;3;31m.\033[0m\n\n\033[0;1;4;33mAccept and continue?\033[0;2m (respond within 30s or \033[1m"Yes"\033[0;2m is assumed)\n\n\033[0;2m(\033[0;1;4;32mY\033[0;1;2;32mes\033[0;2m / \033[0;1;4;31mN\033[0;1;2;31mo\033[0;2m)\033[0m ... '
    # if the user says yes, or force, run the install
    if (($? > 128)) || [[ $REPLY == [Yy]* ]]; then
      echo ''
      setup_home && print_step_complete
    else
      echo -e '\n\n\033[1;31mAborted.\033[0m' && return 1
    fi # $REPLY
  else
    # otherwise (automated install), proceed to setting up the homedir
    setup_home && print_step_complete
  fi # $-

  for cmd_alias in gpg gh starship; do
    # symlink the alias to the actual command for any missing binaries
    if command -v "$cmd_alias" &> /dev/null && [ ! -x "/usr/local/bin/$cmd_alias" ]; then
      sudo command ln -sf "$(command -v "$cmd_alias" 2>&1)" "/usr/local/bin/$cmd_alias"
    fi
  done
  # ensure gpg folder has the right perms
  chmod 700 ~/.gnupg 2>&1

  return 0
}

function cleanup_env() {
  unset -v STEP_NUM STEP_TOTAL verbosity IS_INTERACTIVE IS_DARWIN cmd_alias 2>/dev/null
  unset -f main setup_home setup_node setup_brew print_step_complete print_banner global_add is_interactive 2>/dev/null
}

# run dat shizzle
{
  main "$@" | tee -i -a "$DOTFILES_LOG" 2>&1; # pipe the logs to "$DOTFILES_LOG"
} || code=$?;

# shellcheck disable=SC2248
cleanup_env && unset -f cleanup_env && exit ${code:-0};
