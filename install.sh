#!/usr/bin/env bash

verbosity="--quiet"
OSYS=$(uname | tr '[:upper:]' '[:lower:]')
IS_DARWIN=$(test "$OSYS" = "darwin" && echo -n 1 || echo -n 0)
STEP_NUM=1
STEP_TOTAL=3

export TERM="${TERM:-"xterm-color"}"

if [ -n "$CI" ]; then
  verbosity="--verbose"
fi

function curdir() {
  echo -n "$(readlink "$(test -z "$CI" && echo -n "-f" || echo -n "-n")" "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null || echo -n "$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)")"
}

DOTFILES_LOG="$(curdir 2>/dev/null || echo -n "$HOME/.dotfiles")/.install.$(date +%s).log"

function link_dir () {
  local FILE DIR="$(curdir)" d b src
  src="${DIR:+"$DIR/"}${1-}"
  if [ -d "$src" ]; then
    for FILE in $(find "$src" -type f -name "${2:-"*"}" -not -name "*.swp"); do
      d="$(dirname -- "$FILE" | sed -e 's|\('"$DIR"'\)|'"$HOME"'|')"
      b="$(basename -- "$FILE")"
      { command mkdir -p -v "$d"; command ln -fn -v "$FILE" "$d/$b"; } >> "$DOTFILES_LOG" 2>&1
    done
  fi
}

# setup our new homedir with symlinks to all the dotfiles
function setup_home() {
  local DIR FILE d b
  DIR="$(curdir)"

  print_banner step $'Linking \033[1;4;33mdotfiles\033[0;1m to \033[1;3;4;36m'"$HOME"

  # .bashrc.d
  link_dir ".bashrc.d" ".*"

  link_dir ".bin" "*"

  # .gitconfig.d
  link_dir ".gitconfig.d" "*"

  # GNUPG
  link_dir ".gnupg" "*.conf"

  # github cli
  link_dir ".config/gh" "*.yml"

  # bash env, etc.
  for FILE in $(find "${DIR:+$DIR}" -type f -name ".*" -not -name ".git*" -not -name ".*swp"); do
    # local d="$(dirname -- "$FILE" | sed -e 's|\('"$DIR"'\)|'"$HOME"'|')"
    local b="$(basename -- "$FILE")"
    command ln -fn -v "$FILE" "$HOME/$b" >> "$DOTFILES_LOG" 2>&1
  done

  # .gitignore and .gitconfig (global)
  {
    command ln -fn -v "$DIR/gitconfig" "$HOME/.gitconfig";
    command ln -fn -v "$DIR/gitignore" "$HOME/.gitignore";
  } >> "$DOTFILES_LOG" 2>&1

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

    brew install "${verbosity-}" --overwrite coreutils starship gh shfmt;
  } >> "$DOTFILES_LOG" 2>&1

  # don't install when we're in a noninteractive environment (read: gitpod dotfiles setup task)
  # otherwise this usually takes > 120s and fails hard thanks to gitpod's rather unreasonable time limit.
  # also, skip this step if we're in CI/CD (github actions), because... money reasons.
  if [ -z "$CI" ] && [[ $- == *i* ]]; then
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
          fontforge \
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
          gem install jekyll bundler;
        fi
      } >> "$DOTFILES_LOG" 2>&1

      # for macOS
      if [ $IS_DARWIN = 1 ]; then
        {
          which rvm &>/dev/null || curl -fsSL https://get.rvm.io | bash -s stable --rails;

          brew tap jeroenknoops/tap
          brew install "${verbosity-}" gcc coreutils gitin gpg gpg-suite pinentry-mac python3;

          export SHELL="${HOMEBREW_PREFIX:-}/bin/bash";
          brew install --quiet --cask iterm2;
          curl -fsSL https://iterm2.com/shell_integration/install_shell_integration_and_utilities.sh | bash -;

          # Google Chrome, Prisma, PIA VPN
          brew tap homebrew/cask-versions;
          brew tap homebrew/cask-fonts;
          brew install --casks font-fira-code font-oswald font-ubuntu font-caskaydia-cove-nerd-font fontforge \
            graphql-playground prisma-studio private-internet-access qlmarkdown \
            visual-studio-code visual-studio-code-insiders \
            google-chrome google-chrome-canary firefox firefox-nightly;
        } >> "$DOTFILES_LOG" 2>&1
      else
        brew install --quiet --overwrite gnupg2 xclip
      fi
    fi
}

function global_add() {
  local pkg pkgs=("$@")
  for pkg in "${pkgs[@]}"; do
    pnpm add -g "$pkg" &>/dev/null \
      && echo -e "\\033[1;32m ✓ $pkg \\033[0m" \
      || echo -e "\\033[1;48;2;230;30;30m 𐄂 ${pkg-}\\033[0m";
  done
}

function print_banner () {
  local message divider i
  case "${1-}" in
    (step)
      printf '\033[2m[%d of %d]\033[0m\n\033[1m%s\033[0m\n\n' "$STEP_NUM" "$STEP_TOTAL" "${*:2}"
    ;;
    (*)
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

# installs PNPM and Node.js (if needed) and some minimal global packages
function setup_node() {
  # shellcheck disable=SC2120
  local node_v
  node_v="${1:-lts}"

  print_banner step $'Installing/upgrading \033[1;4;31mPNPM\033[0;1m and \033[4;32mNode\033[0;1;2m ('"$node_v"')'

  {
    if ! which pnpm &>/dev/null; then
      curl -fsSL https://get.pnpm.io/install.sh | bash -;
    fi
    if ! which node &>/dev/null || ! node -v &>/dev/null; then
      (pnpm env use -g "${node_v:-lts}" 2>/dev/null || pnpm env use -g lts) && pnpm setup 2>/dev/null
    fi
  } >> "$DOTFILES_LOG" 2>&1

  global_add zx @antfu/ni dotenv-vault vercel wrangler@latest miniflare@latest
}

# runs all the other scripts and cleans up after itself. geronimo!
function main() {
  clear
  print_banner "Beginning dotfiles installation. This may take a few minutes."
  printf ' \033[1;4m%s\033[0m: %s \n\n' 'Working Dir' "$(curdir)"

  # link the dotfiles to $HOME
  setup_home && print_step_complete

  # setup node and pnpm
  setup_node latest && print_step_complete

  # setup homebrew
  setup_brew && print_step_complete

  # rewrite .bashrc on gitpod setups
  if [ -n "$GITPOD_WORKSPACE_ID" ]; then
    command mv -f ~/.bash_profile ~/.bashrc >> "$DOTFILES_LOG" 2>&1
    git config --global user.name "$GIT_COMMITTER_NAME"
    git config --global user.email "$GIT_COMMITTER_EMAIL"
    git config --global user.signingkey "${GPG_KEY_ID:-$GIT_COMMITTER_EMAIL}"
  fi

  # rebash ;)
  # shellcheck source=/dev/null
  source ~/.bashrc 2>/dev/null
  return 0
}

function cleanup_env () {
  unset -v OSYS IS_DARWIN STEP_NUM STEP_TOTAL verbosity
  unset -f main setup_home setup_node setup_brew print_step_complete print_banner curdir global_add link_dir
}

# run it and clean up after!
(main && cleanup_env && unset -f cleanup_env) && exit 0

# still here? throw codes bro
exit $?
