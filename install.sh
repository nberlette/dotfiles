#!/usr/bin/env bash
# -*- coding: utf-8 -*-

## ------------------------------------------------------------------------ ##
##  install.sh                               Nicholas Berlette, 2022-05-11  ##
## ------------------------------------------------------------------------ ##
##  https://github.com/nberlette/dotfiles/blob/main/install.sh              ##
## ------------------------------------------------------------------------ ##

# ask for password right away
sudo -v

# verbosity flag
# default level is --quiet , in CI/CD --verbose
verbosity="--quiet"
# $OSTYPE variable (linux-gnu, darwin, etc)
[ -z "${OSTYPE:+x}" ] && OSTYPE=$(ostype)
# $IS_DARWIN=1 if on a Mac
[[ "$OSTYPE" == [Dd]arwin* ]] && IS_DARWIN=1 || IS_DARWIN=0;
# $IS_LINUX=1 if on a Linux
[[ "$OSTYPE" == [Ll]inux* ]] && IS_LINUX=1 || IS_LINUX=0;
# $IS_CYGWIN=1 if on a Cygwin
[[ "$OSTYPE" == [Cc]ygwin* ]] && IS_CYGWIN=1 || IS_CYGWIN=0;
# $IS_INTERACTIVE=1 if interactive, 0 otherwise
# (like in CI/CD, or Gitpod autoinstall during prebuilds)
IS_INTERACTIVE=$(test -t 0 && echo -n 1 || echo -n 0)
# current step number
STEP_NUM=1
# total step count
STEP_TOTAL=3

# ensure our $TERM variable is set in CI/CD environments (gh-actions)
[ -z "${TERM:+x}" ] && export TERM="${TERM:-"xterm-color"}"

# current working directory
function curdir() {
  # echo -n "$(readlink "$(test -z "$CI" && echo -n "-f" || echo -n "-n")" "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null
  echo -n "$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
}

[ -f "$(curdir)/.bashrc.d/core.sh" ] && . "$(curdir)/.bashrc.d/core.sh";

DOTFILES_LOG="$(curdir 2>/dev/null || echo -n "$HOME/.dotfiles")/.install.$(date +%s).log"

# always ebable verbose logging if in CI/CD
[ -n "${CI:+x}" ] && verbosity="--verbose"

function ostype() {
  printf "%s" "$(uname -s | tr '[:upper:]' '[:lower:]')"
}

# install homebrew (if needed) and some commonly-used global packages. the bare minimum.
function setup_brew() {

  print_banner step $'Installing/upgrading \033[1;4;35mhomebrew\033[0;1m and required formulae...'
  {
    # install homebrew if not already installed
    if ! which brew &>/dev/null; then
      curl -fsSL https://raw.github.com/Homebrew/install/HEAD/install.sh | bash -
    fi

    # execute now just to be sure its available for us immediately
    eval "$(brew shellenv 2>/dev/null)"

    brew install "${verbosity-}" --overwrite rsync coreutils starship gh git-extras;
    # brew reinstall "${verbosity-}" coreutils starship gh shfmt;
  } | tee -a "$DOTFILES_LOG" 2>&1

  # don't install when we're in a noninteractive environment (read: gitpod dotfiles setup task)
  # otherwise this usually takes > 120s and fails hard thanks to gitpod's rather unreasonable time limit.
  # also, skip this step if we're in CI/CD (github actions), because... money reasons.
  if [ -z "$CI" ] && [[ $- == *i*  || "$IS_INTERACTIVE" == "1" ]]; then
    # install some essentials
    {
      brew install "${verbosity-}" --overwrite \
        gcc \
        cmake \
        make \
        bash \
        git \
        go \
        python \
        jq \
        docker \
        fzf \
        neovim \
        lolcat \
        shellcheck \
        shfmt \
        pygments \
        supabase/tap/supabase ;

      # for developing jekyll sites (and other things for github pages, etc)
      if which gem &>/dev/null; then
        gem install jekyll bundler 2>/dev/null
      fi
    } | tee -a "$DOTFILES_LOG" 2>&1

    # for macOS
    if [ "$IS_DARWIN" = 1 ]; then
      {
        which rvm &>/dev/null || curl -fsSL https://get.rvm.io | bash -s stable --rails;

        brew tap jeroenknoops/tap
        brew install "${verbosity-}" gcc coreutils gitin gpg gpg-suite pinentry-mac python3;
        export SHELL="${HOMEBREW_PREFIX:-}/bin/bash";

        # if interactive and on macOS, we're probably on a macbook / iMac desktop. so add casks. (apps)
        if [[ "$IS_INTERACTIVE" == "1" ]]; then
          brew install --quiet --cask iterm2;
          curl -fsSL https://iterm2.com/shell_integration/install_shell_integration_and_utilities.sh | bash -;
          # Google Chrome, Prisma, PIA VPN
          brew tap homebrew/cask-versions;
          brew tap homebrew/cask-fonts;
          brew install --casks font-fira-code font-oswald font-ubuntu font-caskaydia-cove-nerd-font fontforge \
            graphql-playground prisma-studio private-internet-access qlmarkdown \
            visual-studio-code visual-studio-code-insiders \
            google-chrome google-chrome-canary firefox firefox-nightly;
        fi
      } | tee -a "$DOTFILES_LOG" 2>&1
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

  print_banner step $'Installing/upgrading \033[1;4;31mPNPM\033[0;1m and \033[4;32mNode\033[0;1;2m ('"$node_v"')'

  {
    # install pnpm if not already installed
    if ! which pnpm &>/dev/null; then
      curl -fsSL https://get.pnpm.io/install.sh | bash -;
    fi
    # ensure we have node.js installed
    if ! which node &>/dev/null || ! node -v &>/dev/null; then
      { pnpm env use -g "${node_v:-lts}" 2>/dev/null || pnpm env use -g latest; } && pnpm setup 2>/dev/null
    fi
  } | tee -a "$DOTFILES_LOG" 2>&1

  global_add zx @brlt/n @brlt/prettier prettier dotenv-vault vercel wrangler@latest miniflare@latest @railway/cli prettier degit

  print_step_complete
}

# setup our new homedir with symlinks to all the dotfiles
function setup_home() {
  local DIR FILE d b backupdir
  DIR="$(curdir)"
  # backup (preserving homedir structure), e.g. /home/gitpod/.dotfiles/.backup/home/gitpod/.bashrc~
  backupdir="$HOME/.dotfiles/.backup$HOME"
  [ -d $backupdir ] || mkdir -p $backupdir &>/dev/null

  # this part used to use (and most other dotfiles projects still do) symlinks/hardlinks between
  # the ~/.dotfiles folder and the homedir, but it now uses the rsync program for configuring the
  # homedir. while it is an external dependency, it is much more performant, reliable, portable,
  # and maintainable. +/- ~100 lines of code were replaced by 1 line... and it creates backups ;)

  # define exclusions with .rsyncignore; define files to copy with .rsyncinclude file
	rsync -avh --mkpath --backup --backup-dir=$backupdir --whole-file --files-from=.rsyncfiles --exclude-from=.rsyncignore . ~  | tee -a "$DOTFILES_LOG"
  # .gitignore and .gitconfig are special: we have to rename them to avoid issues with git applying them to the repository
  rsync -avh --mkpath --backup --backup-dir=$backupdir --whole-file gitignore ~/.gitignore | tee -a "$DOTFILES_LOG"
  rsync -avh --mkpath --backup --backup-dir=$backupdir --whole-file gitconfig ~/.gitconfig | tee -a "$DOTFILES_LOG"

  source ~/.bashrc 2>/dev/null
}

function print_banner () {
  local message divider i
  case "${1-}" in
    step)
      printf '\033[2m[%d of %d]\033[0m\n\033[1m%s\033[0m\n\n' "$STEP_NUM" "$STEP_TOTAL" "${*:2}"
    ;;
    *)
        divider="" divider_char="-"
        if [[ ${#1} == 1 && -n "$2" ]]; then
          divider_char="${1:-"-"}"
          message="${*:2}"
        else
          message="${*:-"Beginning dotfiles installation"}"
        fi
        for ((i=0;$i<${COLUMNS:-100};i++)); do
          divider+="${divider_char:-"="}"
        done
        printf '\n\033[1m %s \033[0m\n\033[2m%s\033[0m\n' "${message-}" "${divider-}"
    ;;
  esac
}

function print_step_complete () {
  if (($# > 0)); then
    printf '\n\033[1;48;2;40;60;66;38;2;240;240;240m %s \033[0;2;3m %s\n\n' "${1-}" "${*:2}"
  else
    # display the completed step number and total number of steps
    echo -e '\n\033[1;32m ✓ Completed step '"$STEP_NUM"' of '"$STEP_TOTAL"'.\033[0m\n\n'
    # increment step number by 1
    ((STEP_NUM++))
  fi
}

# runs all the other scripts and cleans up after itself. geronimo!
function main() {
  local flags
  flags="$*"

  # make sure we are in the root ~/.dotfiles directory
  cd "${DOTFILES_PREFIX:-$HOME/.dotfiles}"

  print_banner "Beginning dotfiles installation. This could take a while..."
  printf ' \033[1;4m%s\033[0m: %s \n\n' 'Working Dir' "$(curdir)"

  # setup homebrew and install some packages / formulae
  setup_brew

  # setup pnpm + node.js and install some global packages I frequently use
  setup_node latest

  ## syncing the home directory ###################################################################
  print_banner step $'Syncing \033[1;4;33mdotfiles\033[0;1m to \033[1;3;4;36m'"$HOME"

  if [ "$IS_INTERACTIVE" -ne "1" ]; then
    echo $'\n\033[1;4;33mWARNING\033[0;1m~/.dotfiles/install.sh\033[1;31m is not being run interactively.\033[0m'
    setup_home && print_step_complete && return 0
  else
    if [[ "${flags:+$flags}" =~ ^([-]{1,2}(y(es)?|f(orce)?))$ ]]; then
      setup_home && print_step_complete && return 0
    else
      # if we are in interactive mode, and not forcing, ask the user if they want to proceed
      if [[ $- == *i* ]]; then
        read -p $'\n\033[1;7;33m⚠ DANGER! ⚠\033[0;33m If you proceed with install, this will discard <probably important> configuration files in your homedir!\033[0m\n\n\033[1;3mWant to accept the risk and continue...?\033[0;2m Y[es]/N[o]/F[lip a coin] \033[0m' -n 1
        echo ""
        # if the user says yes, or force, run the install
        if [[ "$REPLY" =~ ^[Yy]$ ]]; then
          setup_home && print_step_complete && return 0
        else
          echo -e '\n\033[1;31mAborted.\033[0m' && exit 1
        fi # $REPLY
      fi # $-
    fi # $flags
  fi # $IS_INTERACTIVE

  # print_step_complete

  return 0
}

function cleanup_env () {
  unset -v STEP_NUM STEP_TOTAL verbosity
  unset -f main setup_home setup_node setup_brew print_step_complete print_banner curdir global_add link_die
}

# run it and clean up after!
{ main "$@" && cleanup_env && unset -f cleanup_env; } || exit $?
exit 0
