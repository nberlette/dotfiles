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
if ! hash ostype &>/dev/null; then
  function ostype() {
    uname -s | tr '[:upper:]' '[:lower:]' 2>/dev/null
  }
fi

# check for is_interactive
if ! hash is_interactive &>/dev/null; then
  function is_interactive()
  {
    # if we're in CI/CD, return code 1 immediately
    if [ -n "$CI" ]; then return 1; fi

    # no? okay, lets check for tty based on stdin, stdout, stderr
    if [ -t 0 ] && [ -t 1 ] && [ -t 2 ]; then return 0; fi

    # no? then we will check shellargs for -i as a last resort
    case $- in (*i*) return 0;; esac

    # ..... no?! you're still here? throw an error >_>
    return 2
  }
fi

# check for curdir
if ! hash curdir &>/dev/null; then
  # determine actual script location
  # shellcheck disable=SC2120
  function curdir() {
    dirname -- "$(realpath -Lmq "${1:-"${BASH_SOURCE[0]}"}" 2>/dev/null)"
  }
fi

# check for global_add
if ! hash global_add &>/dev/null; then
  # installs all arguments as global packages
  function global_add()
  {
    local pkg pkgs=("$@") agent=npm command="i -g"
    if command -v yarn &>/dev/null; then
      agent="$(command -v yarn)"
      command="global add"
    else
      agent="$(command -v pnpm 2>/dev/null || command -v npm 2>/dev/null)"
      command="i -g"
    fi
    $agent "$command" "${pkgs[@]}" &>/dev/null && {
      echo "Installed with $agent:"
      for pkg in "${pkgs[@]}"; do
        echo -e "\\033[1;32m ✓ $pkg \\033[0m"
        # || echo -e "\\033[1;48;2;230;30;30m 𐄂 ${pkg-}\\033[0m";
      done
    }
  }

fi

function setup_env()
{
  declare -l DOTFILES_CORE
  declare -g IS_INTERACTIVE DOTFILES_PREFIX
  declare -g -r DOTFILES_LOG DOTFILES_LOGPATH DOTFILES_BACKUP_PATH

  # $OSTYPE variable (linux-gnu, darwin, etc)
  [ -z "${OSTYPE:+x}" ] && OSTYPE=$(ostype)

  # $IS_DARWIN=1 if on a Mac
  [[ "$OSTYPE" == [Dd]arwin* ]] && IS_DARWIN=1 || IS_DARWIN=0

  # IS_INTERACTIVE=1 if interactive, 0 otherwise (duh)
  # (like in CI/CD, or Codespaces/Gitpod autoinstall during prebuilds)
  IS_INTERACTIVE="$(is_interactive 2>&1)"

  export TZ='America/Los_Angeles'
  export DOTFILES_PREFIX="${DOTFILES_PREFIX:-"$HOME/.dotfiles"}"

  export DOTFILES_LOGPATH="$DOTFILES_PREFIX/_installs/$(date +%F)-$(date +%s)"
  export DOTFILES_LOG="${DOTFILES_LOGPATH-}/install.log"
  export DOTFILES_BACKUP_PATH="${DOTFILES_LOGPATH}/.backup"
  [ -d "$DOTFILES_LOGPATH" ] || mkdir -p "$DOTFILES_LOGPATH" &>/dev/null;
  [ -d "$DOTFILES_BACKUP_PATH" ] || mkdir -p "$DOTFILES_BACKUP_PATH" &>/dev/null;
  command touch "$DOTFILES_LOG" &>/dev/null;

  DOTFILES_CORE="$(curdir 2>/dev/null || echo -n "$DOTFILES_PREFIX")/.bashrc.d/core.sh"

  # shellcheck source=/dev/null
  [ -r "$DOTFILES_CORE" ] && . "$DOTFILES_CORE"

  cd "$(curdir)" 2>/dev/null || exit 1;
}

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

function print_step_complete()
{
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

  print_banner step $'Installing/upgrading \033[1;4;35mhomebrew\033[0;1m and required formulae...'
  {
    # install homebrew if not already installed
    if ! command -v brew &>/dev/null; then
      curl -fsSL https://raw.github.com/Homebrew/install/HEAD/install.sh | bash -
    fi

    # execute now just to be sure its available for us immediately
    eval "$(brew shellenv 2>/dev/null)"

    brew install "${verbosity-}" --overwrite rsync coreutils gh git-extras
    # brew reinstall "${verbosity-}" coreutils starship gh shfmt;
  } | tee -i -a "$DOTFILES_LOG" 2>&1

  # don't install when we're in a noninteractive environment (read: gitpod dotfiles setup task)
  # otherwise this usually takes > 120s and fails hard thanks to gitpod's rather unreasonable time limit.
  # also, skip this step if we're in CI/CD (github actions), because... money reasons.
  if [ -z "${CI:+x}" ] && [ -n "${IS_INTERACTIVE+x}" ]; then
    read -r -n 1 -i y -t 30 -p $'\n\033[0;1;5;33m⚠  \033[0m \033[1;33mInstall/update core utilities like git, go, docker, bash, etc.?\033[0m\n\n\033[0;2m(might add 5+ minutes to install)\n\n\033[0;2m(\033[0;1;32mY\033[0;1;2;32mes\033[0;3m / \033[0;1;31mN\033[0;1;2;31mo\033[0;2m)\033[0m ... '
    local prompt_status=$?
    echo ''

    if [[ $REPLY =~ ^[Yy]$ ]] || ((prompt_status > 128)); then
      # install some essentials
      {
        brew install "${verbosity-}" --overwrite \
          gcc \
          cmake \
          make \
          bash \
          git \
          go \
          jq \
          docker \
          fzf \
          neovim \
          lolcat \
          shellcheck \
          shfmt \
          pygments \
          supabase/tap/supabase

        # for developing jekyll sites (and other things for github pages, etc)
        if command -v gem &>/dev/null; then
          gem install jekyll bundler 2>/dev/null
        fi
      } | tee -i -a "$DOTFILES_LOG" 2>&1
    fi

    # for macOS
    if [ "$IS_DARWIN" = 1 ]; then
      {
        command -v rvm &>/dev/null || curl -fsSL https://get.rvm.io | bash -s stable --rails

        brew tap jeroenknoops/tap
        brew install "${verbosity-}" gcc coreutils gitin gpg gpg-suite pinentry-mac
        export SHELL="${HOMEBREW_PREFIX:-}/bin/bash"

        # if interactive and on macOS, we're probably on a macbook / iMac desktop. so add casks. (apps)
        read -r -n 1 -i y -t 30 -p $'\n\033[0;1;5;33m⚠  \033[0m \033[1;33mInstall or upgrade \033[3;4mall\033[0;1;33m macOS apps, addons, and fonts?\033[0m\n\n\033[0;2m(could take up to ten minutes to complete)\n\n\033[0;2m(\033[0;1;32mY\033[0;1;2;32mes\033[0;2m / \033[0;1;31mN\033[0;1;2;31mo\033[0;2m)\033[0m ... '
        local prompt_status=$?
        echo ''

        if [[ $REPLY =~ ^[Yy]$ ]] || ((prompt_status > 128)); then
          brew install --quiet python3 fontforge
          brew install --quiet --cask iterm2
          curl -fsSL https://iterm2.com/shell_integration/install_shell_integration_and_utilities.sh | bash -
          # Google Chrome, Prisma, PIA VPN
          brew tap homebrew/cask-versions
          brew tap homebrew/cask-fonts
          brew install --casks font-fira-code font-oswald font-ubuntu font-caskaydia-cove-nerd-font fontforge \
            graphql-playground prisma-studio private-internet-access qlmarkdown \
            visual-studio-code visual-studio-code-insiders \
            google-chrome google-chrome-canary firefox firefox-nightly
        else
          ((STEP_NUM++))
        fi
      } | tee -i -a "$DOTFILES_LOG" 2>&1
    else
      brew install --quiet --overwrite gnupg2 xclip
    fi
  fi

  print_step_complete
}

# installs PNPM and Node.js (if needed) and some minimal global packages
function setup_node() {
  # shellcheck disable=SC2120
  local node_v
  node_v="${1:-lts}"

  print_banner step $'Installing/upgrading \033[1;4;31mPNPM\033[0;1m and \033[4;32mNode\033[0;1;2m v'"$node_v"$'\033[0m'

  {
    # install pnpm if not already installed
    if ! command -v pnpm &>/dev/null; then
      curl -fsSL https://get.pnpm.io/install.sh | bash -
    fi
    # ensure we have node.js installed
    if ! command -v node &>/dev/null || ! node -v &>/dev/null; then
      { pnpm env use -g "${node_v:-lts}" 2>/dev/null || pnpm env use -g 16.15.0; } && pnpm setup 2>/dev/null
    fi
  } | tee -i -a "$DOTFILES_LOG" 2>&1

  global_add zx @brlt/n @brlt/prettier prettier @brlt/eslint-config eslint @brlt/utils degit

  read -r -n 1 -i y -t 30 -p $'\n\033[0;1;5;33m⚠  \033[0m\033[1;33mInstall CLIs for Vercel/Railway/Netlify/Cloudflare?\033[0m\n\n\033[0;2m(\033[0;1;4;32mY\033[0;1;2;32mes\033[0;2m / \033[0;1;4;31mN\033[0;1;2;31mo\033[0;2m)\033[0m ... '
  local prompt_status=$?
  echo ''

  if [[ $REPLY =~ ^[Yy]$ ]] || (("$prompt_status" > 128)); then
    global_add dotenv-vault vercel wrangler@latest miniflare@latest @railway/cli netlify-cli
  else
    ((STEP_NUM++))
  fi

  print_step_complete "$@"
}

# setup our new homedir with symlinks to all the dotfiles
function setup_home() {
  # backup (preserving homedir structure), e.g. /home/gitpod/.dotfiles/.backup/home/gitpod/.bashrc~
  [ -d "${DOTFILES_BACKUP_PATH-}" ] || mkdir -p "${DOTFILES_BACKUP_PATH-}" &>/dev/null

  # this part used to use (and most other dotfiles projects still do) symlinks/hardlinks between
  # the ~/.dotfiles folder and the homedir, but it now uses the rsync program for configuring the
  # homedir. while it is an external dependency, it is much more performant, reliable, portable,
  # and maintainable. +/- ~100 lines of code were replaced by 1 line... and it creates backups ;)

  # define exclusions with .rsyncignore; define files to copy with .rsyncinclude file
  rsync -avh --backup --backup-dir="${DOTFILES_BACKUP_PATH-}" --whole-file --files-from=.rsyncfiles --exclude-from=.rsyncignore . ~ | tee -i -a "$DOTFILES_LOG" 2>&1

  # .gitignore and .gitconfig are special!
  # we have to rename them to avoid issues with git applying them to the repository
  mv -f ~/.{gitignore,gitconfig} "${DOTFILES_BACKUP_PATH-}" &>/dev/null

  rsync -avh --backup --backup-dir="${DOTFILES_BACKUP_PATH-}" --whole-file gitignore ~/.gitignore | tee -i -a "$DOTFILES_LOG" 2>/dev/null
  rsync -avh --backup --backup-dir="${DOTFILES_BACKUP_PATH-}" --whole-file gitconfig ~/.gitconfig | tee -i -a "$DOTFILES_LOG" 2>/dev/null

  return 0
}

# runs all the other scripts and cleans up after itself. geronimo!
function main() {
  # make sure we are in the root ~/.dotfiles directory
  cd "${DOTFILES_PREFIX:-$HOME/.dotfiles}" || return

  print_banner "Spooling up the dotfiles installer..."
  printf ' \033[1;4m%s\033[0m: %s \n\n' 'Working Dir' "$(curdir)"

  # if we are in a github codespaces environment, skip homebrew setup for now.
  # currently the homebrew installer breaks due to a git syntax error in their code. works fine in gitpod though. 🤔
  if [ -n "${CODESPACES+x}" ]; then
    STEP_TOTAL=2 # adjust step total since we're skipping homebrew
    { curl -sS https://starship.rs/install.sh | sh -; }
  else
    STEP_TOTAL=3
    # for everything else, setup homebrew and install some packages / formulae
    setup_brew
    brew install --quiet --overwrite starship
  fi

  # setup pnpm + node.js and install some global packages I frequently use
  # pin node.js to 16.14.2 to prevent breaking errors
  setup_node "16.15.0"

  # syncing the home directory
  print_banner step $'Syncing \033[1;4;33mdotfiles\033[0;1m to \033[1;3;4;36m'"$HOME"

  # if we are in interactive mode (not in CI/CD), ask the user if they want to proceed
  if is_interactive 2>/dev/null; then
    read -r -n 1 -i y -t 30 -p $'\n\033[0;1;5;33m⚠  \033[0;1;31m DANGER \033[0m ·  \033[3;31mContinuing with install will overwrite existing files in \033[3;4m'"$HOME"$'\033[0;3;31m.\033[0m\n\n\033[0;1;4;33mAccept and continue?\033[0;2m (respond within 30s or \033[1m"Yes"\033[0;2m is assumed)\n\n\033[0;2m(\033[0;1;4;32mY\033[0;1;2;32mes\033[0;2m / \033[0;1;4;31mN\033[0;1;2;31mo\033[0;2m)\033[0m ... '
    # if the user says yes, or force, run the install
    if (($? > 128)) || [[ "$REPLY" == [Yy]* ]]; then
      echo ''
      setup_home && print_step_complete;
    else
      echo -e '\n\n\033[1;31mAborted.\033[0m' && return 1;
    fi # $REPLY
  else
    # otherwise (automated install), proceed to setting up the homedir
      setup_home && print_step_complete;
  fi   # $-

  for cmd_alias in gpg gh starship; do
    # symlink the alias to the actual command for any missing binaries
    if command -v "$cmd_alias" &>/dev/null && [ ! -x "/usr/local/bin/$cmd_alias" ]; then
      sudo command ln -sf "$(command -v "$cmd_alias" 2>&1)" "/usr/local/bin/$cmd_alias"
    fi
  done
  # ensure gpg folder has the right perms
  chmod 700 ~/.gnupg 2>&1

  return 0
}

function cleanup_env() {
  unset -v STEP_NUM STEP_TOTAL verbosity IS_INTERACTIVE IS_DARWIN cmd_alias
  unset -f main setup_home setup_node setup_brew print_step_complete print_banner global_add is_interactive setup_env
}

# run it and clean up after!
{ setup_env 2>/dev/null; main "$@" || exit $?; } | tee -i -a "$DOTFILES_LOG" 2>&1;

cleanup_env && unset -f cleanup_env
exit 0
