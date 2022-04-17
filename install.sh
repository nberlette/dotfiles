#!/usr/bin/env bash

verbosity="--quiet"
OSYS=$(uname | tr '[:upper:]' '[:lower:]')
IS_DARWIN=$(test "$OSYS" = "darwin" && echo -n 1 || echo -n 0)
DOTFILES_LOG=~/.dotfiles/.install.log
STEP_NUM=1
STEP_TOTAL=3

export TERM="${TERM:-"xterm-color"}"

if [ -n "$CI" ]; then
  verbosity="--verbose"
fi

function curdir() {
  echo -n "$(readlink $(test -z "$CI" && echo -n "-f" || echo -n "-n") "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null || echo -n "$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)")"
}

function link_dir () {
  local FILE DIR="$(curdir)" d b
  for FILE in $(find "${DIR:+"$DIR/"}${1-}" -type f -name "${2:-"*"}" -not -name "*.swp"); do
    d="$(dirname -- "$FILE" | sed -e 's|\('"$DIR"'\)|'"$HOME"'|')"
    b="$(basename -- "$FILE")"
    command mkdir -p -v "$d" &>> "$DOTFILES_LOG"
    command ln -fn -v "$FILE" "$d/$b" &>> "$DOTFILES_LOG"
  done
}

# setup our new homedir with symlinks to all the dotfiles
function setup_home() {
  local DIR FILE d b
  DIR="$(curdir)"

  print_banner step $'Linking \033[1;4;33mdotfiles\033[0;1m to \033[1;3;4;36m'"$HOME"

  # bash env, etc.
  for FILE in $(find "${DIR:+$DIR}" -type f -name ".*" -not -name ".git*" -not -name ".*swp"); do
    # local d="$(dirname -- "$FILE" | sed -e 's|\('"$DIR"'\)|'"$HOME"'|')"
    local b="$(basename -- "$FILE")"
    command ln -fn -v "$FILE" "$HOME/$b" &>> "$DOTFILES_LOG"
  done

  command ln -fn -v "$DIR/gitconfig" "$HOME/.gitconfig" &>> "$DOTFILES_LOG"
  command ln -fn -v "$DIR/gitignore" "$HOME/.gitignore" &>> "$DOTFILES_LOG"

  link_dir ".bashrc.d" ".*"

  # .gitconfig.d
  link_dir ".gitconfig.d" "*"

  # GNUPG
  link_dir ".gnupg" "*.conf"

  # github cli
  link_dir ".config/gh" "*.yml"
}

# install homebrew (if needed) and some commonly-used global packages. the bare minimum.
function setup_brew() {

  print_banner step $'Installing/upgrading \033[1;4;35mhomebrew\033[0;1m and required formulae...'
  # install homebrew if not already installed
  if ! which brew &>/dev/null; then
    curl -fsSL https://raw.github.com/Homebrew/install/HEAD/install.sh | bash -
  fi

  # execute now just to be sure its available for us immediately
  eval "$(brew shellenv 2>/dev/null)"

  brew install "${verbosity-}" --overwrite starship gh supabase/tap/supabase git-extras  &>> "$DOTFILES_LOG"

  # don't install when we're in a noninteractive environment (read: gitpod dotfiles setup task)
  # otherwise this usually takes > 120s and fails hard thanks to gitpod's rather unreasonable time limit.
  # also, skip this step if we're in CI/CD (github actions), because... money reasons.
  if [ -z "$CI" ] && [[ $- == *i* ]]; then
      # install some essentials
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
      &>> "$DOTFILES_LOG"

      # for developing jekyll sites (and other things for github pages, etc)
      if which gem &>/dev/null; then
        gem install jekyll bundler &>> "$DOTFILES_LOG"
      fi

      # for macOS
      if [ $IS_DARWIN = 1 ]; then
        which rvm &>/dev/null || command curl -fsSL https://get.rvm.io | bash -s stable --rails  &>> "$DOTFILES_LOG"

        brew tap jeroenknoops/tap
        brew install "${verbosity-}" gcc coreutils gitin gpg gpg-suite pinentry-mac python3  &>> "$DOTFILES_LOG"

        export SHELL="${HOMEBREW_PREFIX:-}/bin/bash"
        brew install --quiet --cask iterm2
        curl -fsSL https://iterm2.com/shell_integration/install_shell_integration_and_utilities.sh | bash -

        # Google Chrome, Prisma, PIA VPN
        brew tap homebrew/cask-versions &>> "$DOTFILES_LOG"
        brew tap homebrew/cask-fonts &>> "$DOTFILES_LOG"
        brew install --casks font-fira-code font-oswald font-ubuntu font-caskaydia-cove-nerd-font fontforge \
          graphql-playground prisma-studio private-internet-access qlmarkdown \
          visual-studio-code visual-studio-code-insiders \
          google-chrome google-chrome-canary firefox firefox-nightly &>> "$DOTFILES_LOG"
      else
        brew install --quiet --overwrite gnupg2 xclip &>> "$DOTFILES_LOG"
      fi
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
  local message divider divider_length i
  case "${1-}" in
    (step)
      printf '\033[2m[%d of %d]\033[0;1m %s\033[0m' "$STEP_NUM" "$STEP_TOTAL" "${*:2}"
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
  local delay=3
  if (($# > 0)); then
    printf '\n\033[1;48;2;40;60;66;38;2;240;240;240m %s \033[0;2;3m %s\n\n' "${1-}" "${*:2}"
  else
    # display the completed step number and total number of steps
    echo -e '\n\033[1;32m ✓ Completed step '$STEP_NUM' of '$STEP_TOTAL'.\033[0m\n\n'
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

  # install pnpm if not already installed
  if ! which pnpm &>/dev/null; then
    curl -fsSL https://get.pnpm.io/install.sh | bash - &>> "$DOTFILES_LOG"
  fi

  # install node.js  if we don't have it yet
  if ! which node &>/dev/null || ! node -v &>/dev/null; then
    pnpm env use -g "${node_v:-lts}" 2>/dev/null || pnpm env use -g lts &>> "$DOTFILES_LOG"
  fi

  # global_add @antfu/ni degit @types/node typescript tslib tsm tsup ts-node eslint standard prettier prettier-plugin-sh svelte @sveltejs/kit@next tailwindcss postcss autoprefixer windicss sirv-cli microbundle

  global_add zx @antfu/ni dotenv-vault vercel wrangler@beta miniflare@latest cron-scheduler worktop@next 2>/dev/null
}

# runs all the other scripts and cleans up after itself. geronimo!
function main() {
  local step_cmd
  clear
  print_banner "Beginning dotfiles installation. This may take a few minutes."
  printf ' \033[1;4m%s\033[0m: %s ' 'Working Dir' "$(curdir)"

  for step_cmd in
  setup_home 2>> "$DOTFILES_LOG" && print_step_complete

  setup_node latest 2>> "$DOTFILES_LOG" && print_step_complete

  setup_brew 2>> "$DOTFILES_LOG" && print_step_complete

  cat<<'APPENDPROFILE' >> ~/.bashrc

## added programmatically by install.sh from nberlette/dotfiles ##

# hacky temporary fix to override profile file from my other project gitpod-enhanced
[ -f ~/.bashrc.d/00-gitpod ] || [ -f ~/.bashrc.d/00-profile ] && rm -f ~/.bashrc.d/00-{gitpod,profile} 2>/dev/null

# ensure our profile is included
[ -x ~/.bash_profile ] && source ~/.bash_profile;

APPENDPROFILE

  print_step_complete 'COMPLETE!' 'Restarting shell environment...'
  sleep 2 && clear
  # shellcheck source=/dev/null
  source ~/.bashrc 2>/dev/null
  return 0
}

function cleanup_env () {
  unset -v OSYS IS_DARWIN STEP_NUM STEP_TOTAL DOTFILES_LOG verbosity
  unset -f main setup_home setup_node setup_brew print_step_complete print_banner curdir global_add link_dir
}

# run it and clean up after!
(main && cleanup_env && unset -f cleanup_env) && exit 0

# still here? throw codes bro
exit $?
