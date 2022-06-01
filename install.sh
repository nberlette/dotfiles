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

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )"
source "$SCRIPTS_DIR/.bashrc.d/core.sh"

# verbosity flag
# default level is --quiet , in CI/CD --verbose
verbosity="--quiet"

# always ebable verbose logging if in CI/CD
[ -n "${CI:+x}" ] && verbosity="--verbose"

# current step number, total step count
declare -i STEP_NUM=1
declare -i STEP_TOTAL=1

# export PNPM homedir to unify the virtual dependency store
export PNPM_HOME="${PNPM_HOME:-"$(dirname -- "$(which pnpm)")"}"
# do not automatically cleanup after installing homebrew packages
export HOMEBREW_NO_INSTALL_CLEANUP=1
# do not show env hints during homebrew install process
export HOMEBREW_NO_ENV_HINTS=1
# tell terminal.app to shut the fuck up about switching the shell to zsh
export BASH_SILENCE_DEPRECATION_WARNING=1

# ensure $TERM is set in CI/CD (gh-actions)
[ -z "${TERM:+x}" ] && export TERM="${TERM:-"xterm-color"}"

# $OSTYPE variable (linux-gnu, darwin, etc)
[ -z "${OSTYPE:+x}" ] && OSTYPE=$(ostype)

# $IS_DARWIN=1 if on a Mac
[[ $OSTYPE == [Dd]arwin* ]] && IS_DARWIN=1 || IS_DARWIN="";

export TZ='America/Los_Angeles'

# IS_INTERACTIVE=1 if interactive, 0 otherwise (duh)
# (like in CI/CD, or Codespaces/Gitpod autoinstall during prebuilds)
declare -g -r -x IS_INTERACTIVE="$(is_interactive 2>&1 && echo -n 1)"
declare -g -r -x DOTFILES_PREFIX="${DOTFILES_PREFIX:-"$HOME/.dotfiles"}"
declare -g -r -x DOTFILES_LOGPATH="$DOTFILES_PREFIX/_installs/$(date +%F)-$(date +%s)"
declare -g -r -x DOTFILES_LOG="${DOTFILES_LOGPATH-}/install.log"
declare -g -r -x DOTFILES_BACKUP_PATH="${DOTFILES_LOGPATH}/.backup"

# ensure our log folder and backup folder exist
[ -d "$DOTFILES_LOGPATH" ] || mkdir -p "$DOTFILES_LOGPATH" &> /dev/null
[ -d "$DOTFILES_BACKUP_PATH" ] || mkdir -p "$DOTFILES_BACKUP_PATH" &> /dev/null

# create the install log file
command touch "$DOTFILES_LOG" &> /dev/null

# source the dotfiles core shell files
DOTFILES_CORE="$(curdir 2> /dev/null || echo -n "$DOTFILES_PREFIX")/.bashrc.d/core.sh"
# shellcheck source=/dev/null
[ -r "$DOTFILES_CORE" ] && . "$DOTFILES_CORE"

# change directories back into the parent folder of the install.sh file (to be safe)
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
      printf '\n\033[1;2m(step #%d) \033[0;1m%s\033[0m\n' "$STEP_NUM" "${*:2}";
      ((STEP_TOTAL++));;
    *)
      divider="" divider_char="-"
      if (($# > 1)) && [ -n "$2" ]; then
        divider_char="${1:-"-"}"
        message="${*:2}"
      else
        message="${*:-"Beginning dotfiles installation"}"
      fi
      for ((i = 0; i < 80; i++)); do
        divider+="${divider_char:-"="}"
      done
      printf '\n\033[1m %s \033[0m\n\033[2m%s\033[0m\n' "${message-}" "${divider-}"
      ;;
  esac
}

# shellcheck disable=SC2120
function print_step_complete() {
  if (($# > 0)); then
    printf '\n\033[1;48;2;40;60;66;38;2;240;240;240m %s \033[0;2;3m %s\n\n' "${1-}" "${*:2}"
  else
    # display the completed step number and total number of steps
    echo -e '\n\033[1;32m ✓ \033[0;32;3mCompleted step '"$STEP_NUM"'.\033[0m\n'
    # increment step number by 1
    ((STEP_NUM++))
  fi
}

# install homebrew (if needed) and some commonly-used global packages. the bare minimum.
function setup_brew() {
  local HOMEBREW_BUNDLE_FILE

  {
    # install homebrew if not already installed
    if ! command -v brew &> /dev/null; then
      curl -fsSL https://raw.github.com/Homebrew/install/HEAD/install.sh | bash -
    fi
    # execute now just to be sure its available for us immediately
    eval "$(brew shellenv 2> /dev/null)"
  } 2>&1

  # set our brewfile location
  HOMEBREW_BUNDLE_FILE="$(realpath -eLq "${DOTFILES_PREFIX-}/.Brewfile" 2> /dev/null || echo -n "$DOTFILES_PREFIX/.Brewfile")"
  export HOMEBREW_BUNDLE_FILE

  # don't install when we're in a noninteractive environment (read: gitpod dotfiles setup task)
  # otherwise this usually takes > 120s and fails hard thanks to gitpod's rather unreasonable time limit.
  # also, skip this step if we're in CI/CD (github actions), because... money reasons.
  if [ -z "${CI:+x}" ] && [ -n "${IS_INTERACTIVE+x}" ]; then
    # for developing jekyll sites (and other things for github pages, etc)
    if command -v gem &> /dev/null; then
      gem install jekyll bundler 2>&1
    fi
    # for macOS
    if [ "$IS_DARWIN" = 1 ]; then
      HOMEBREW_BUNDLE_FILE="$(realpath -eLq "${DOTFILES_PREFIX-}/.osx/.Brewfile" 2>/dev/null || echo -n "$DOTFILES_PREFIX/.osx/.Brewfile")"
      export HOMEBREW_BUNDLE_FILE

      { command -v rvm &> /dev/null || curl -fsSL https://get.rvm.io | bash -s stable --rails; } 2>&1
      export SHELL="${HOMEBREW_PREFIX:-}/bin/bash"
    fi
  fi

  if [ -r "$HOMEBREW_BUNDLE_FILE" ]; then
    # make sure its executable...
    [ -x "$HOMEBREW_BUNDLE_FILE" ] || chmod +x "$HOMEBREW_BUNDLE_FILE" 2>/dev/null;
    # and then execute it
    brew bundle install "${verbosity-}" --no-lock 2>&1
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
  } 2>&1

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
    # STEP_NUM=$((STEP_NUM+1))
  fi

  return 0
}

# setup our new homedir with symlinks to all the dotfiles
function setup_home() {
  local rsyncfiles rsyncexclude rsyncinclude git_file
  local -a rsyncargs=("-avh" "--recursive" "--perms" "--times" "--checksum" "--itemize-changes" "--human-readable" "--progress" "--log-file=$DOTFILES_LOG" "--backup" "--backup-dir=$DOTFILES_BACKUP_PATH")

  # first off, install rsync if it doesn't exist on the current system
  if ! command -v rsync &> /dev/null; then
    brew install --force --overwrite --quiet rsync >> "$DOTFILES_LOG" 2>&1
  fi

  # backup (preserving homedir structure), e.g. /home/gitpod/.dotfiles/.backup/home/gitpod/.bashrc~
  [ -d "${DOTFILES_BACKUP_PATH-}" ] || mkdir -p -v "${DOTFILES_BACKUP_PATH-}" | tee -i -a "$DOTFILES_LOG" 2>&1

  # set the default locations for .rsyncfiles and .rsyncexclude files
  rsyncfiles="${DOTFILES_PREFIX-}/.rsyncfiles"
  rsyncexclude="${DOTFILES_PREFIX-}/.rsyncexclude"
  rsyncinclude="${DOTFILES_PREFIX-}/.rsyncinclude"

  # .gitignore and .gitconfig are special!
  # we have to rename them to avoid issues with git applying them to the repository
  for git_file in "gitignore" "gitconfig"; do
    { [ -e ~/."$git_file" ] && mv -f -v ~/."$git_file" "${DOTFILES_BACKUP_PATH-}"; } | tee -i -a "$DOTFILES_LOG" 2>&1
    rsync "${rsyncargs[@]}" "$git_file" ~/."$git_file" ;
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
  rsync "${rsyncargs[@]}" "$(curdir 2>/dev/null || echo -n "${DOTFILES_PREFIX:-"$HOME/.dotfiles"}")" "$HOME";

  return 0
}

# runs all the other scripts and cleans up after itself. geronimo!
function main() {
  # make sure we are in the root ~/.dotfiles directory
  cd "${DOTFILES_PREFIX-}" || return ;

  clear &> /dev/null; # clear the screen of any previous output

  print_banner "Spooling up the dotfiles installer..."
  printf ' \033[1;4m%s\033[0m: %s \n\n' 'Working Dir' "$(curdir)"

  # if we are in a github codespaces environment, skip homebrew setup for now.
  # currently the homebrew installer breaks due to a git syntax error in their code. works fine in gitpod though. 🤔
  if [ -n "${CODESPACES+x}" ]; then
    # STEP_TOTAL=2 # adjust step total since we're skipping homebrew
    curl -sS https://starship.rs/install.sh | sh - ;
  fi

  print_banner step $'Installing/upgrading \033[1;4;35mhomebrew\033[0;1m and required formulae...\033[0m\n'
  if is_interactive 2>/dev/null || [ -n "${IS_INTERACTIVE+x}" ]; then
    print_banner step $'\033[0;1;5;31m ☢︎ \033[0;1;2;3;33m(this may take a while)\033[0m\n'
    {
      setup_brew | tee -i -a "$DOTFILES_LOG" 2>&1;
    # shellcheck disable=SC2119
    } && print_step_complete

  fi

  print_banner step "$(printf 'Installing/upgrading \033[1;4;31mPNPM\033[0;1m and \033[4;32mNode\033[0;1;2m v%s\033[0m' "${node_v:-LTS}")"
  # pin node.js to 16.14.2 to prevent breaking errors
  {
    setup_node "16.15.0" | tee -i -a "$DOTFILES_LOG" 2>&1;
  # shellcheck disable=SC2119
  } && print_step_complete

  # syncing the home directory
  print_banner step $'Syncing \033[1;4;33mdotfiles\033[0;1m to \033[1;3;4;36m'"$HOME"
  # if we are in interactive mode (not in CI/CD), ask the user if they want to proceed
  if is_interactive 2>/dev/null || [ -n "${IS_INTERACTIVE+x}" ]; then
    read -r -n 1 -i y -t 30 -p $'\n\033[0;1;5;33m⚠  \033[0;1;31m DANGER \033[0m ·  \033[3;31mContinuing with install will overwrite existing files in \033[3;4m'"$HOME"$'\033[0;3;31m.\033[0m\n\n\033[0;1;4;33mAccept and continue?\033[0;2m (respond within 30s or \033[1m"Yes"\033[0;2m is assumed)\n\n\033[0;2m(\033[0;1;4;32mY\033[0;1;2;32mes\033[0;2m / \033[0;1;4;31mN\033[0;1;2;31mo\033[0;2m)\033[0m ... '
    # if the user says yes, or force, run the install
    if (($? > 128)) || [[ $REPLY == [Yy]* ]]; then
      echo ''
      {
        setup_home | tee -i -a "$DOTFILES_LOG" 2>&1;
      # shellcheck disable=SC2119
      } && print_step_complete
    else
      echo -e '\n\n\033[1;31mAborted.\033[0m' && return 1
    fi # $REPLY
  else
    # otherwise (automated install), proceed to setting up the homedir
    {
      setup_home | tee -i -a "$DOTFILES_LOG" 2>&1;
    # shellcheck disable=SC2119
    } && print_step_complete
  fi # $-

  for cmd_alias in gpg gh starship; do
    # symlink the alias to the actual command for any missing binaries
    if command -v "$cmd_alias" &> /dev/null && [ ! -x "/usr/local/bin/$cmd_alias" ]; then
      sudo ln -sf "$(command -v "$cmd_alias" 2>&1)" "/usr/local/bin/$cmd_alias"
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
{ main "$@" || code=$?; }

# shellcheck disable=SC2248
cleanup_env && unset -f cleanup_env &> /dev/null && exit ${code:-0};
