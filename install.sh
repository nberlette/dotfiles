#!/usr/bin/env bash

OSYS="$(uname | tr '[:upper:]' '[:lower:]')"
[ "$OSYS" = "darwin" ] && export IS_DARWIN=1
[ -z "$CI" ] && verbosity="--quiet" || verbosity="--verbose"
[ -z "$TERM" ] && export TERM=xterm

STEP_NUM=1
STEP_TOTAL=3

function curdir() {
  echo -n "$(readlink $(test -z "$CI" && echo -n "-f" || echo -n "-n") "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null || echo -n "$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)")"
}

# setup our new homedir with symlinks to all the dotfiles
function setup_home() {
  local DIR FILE d b
  DIR="$(curdir)"

  # bash env, etc.
  for FILE in $(find "${DIR:+$DIR}" -type f -name ".*" -not -name ".git*" -not -name ".*swp"); do
    # local d="$(dirname -- "$FILE" | sed -e 's|\('"$DIR"'\)|'"$HOME"'|')"
    local b="$(basename -- "$FILE")"
    ln -fn -v "$FILE" "$HOME/$b"
  done

  # .gitconfig.d
  for FILE in $(find "${DIR:+"$DIR/"}.gitconfig.d" -type f -name "*" -not -name "*.swp" -not -name ".*"); do
    d="$(dirname -- "$FILE" | sed -e 's|\('"$DIR"'\)|'"$HOME"'|')"
    b="$(basename -- "$FILE")"
    mkdir -p "$d" >/dev/null 2>&1
    ln -fn -v "$FILE" "$d/$b"
  done

  ln -fn -v "$DIR/gitconfig" "$HOME/.gitconfig"
  ln -fn -v "$DIR/gitignore" "$HOME/.gitignore"

  # GNUPG
  for FILE in $(find "${DIR:+"$DIR/"}.gnupg" -type f -name "*.conf"); do
    d="$(dirname -- "$FILE" | sed -e 's|\('"$DIR"'\)|'"$HOME"'|')"
    b="$(basename -- "$FILE")"
    mkdir -p "$d" >/dev/null 2>&1
    ln -fn -v "$FILE" "$d/$b"
  done

  # github cli
  for FILE in $(find "${DIR:+"$DIR/"}.config/gh" -type f -name "*.yml"); do
    d="$(dirname -- "$FILE" | sed -e 's|\('"$DIR"'\)|'"$HOME"'|')"
    b="$(basename -- "$FILE")"
    mkdir -p "$d" >/dev/null 2>&1
    ln -fn -v "$FILE" "$d/$b"
  done
}

# install homebrew (if needed) and some commonly-used global packages. the bare minimum.
function setup_brew() {
  print_banner step $'Installing/upgrading \033[1;4;35mhomebrew\033[0;1m and required formulae...'
  # install homebrew if not already installed
  if ! which brew >&/dev/null; then
    curl -fsSL https://raw.github.com/Homebrew/install/HEAD/install.sh | bash -
  fi

  # execute now just to be sure its available for us immediately
  eval "$(brew shellenv 2>/dev/null)"

  brew install "${verbosity-}" --overwrite starship gh supabase/tap/supabase

  # don't install when we're in a gitpod environment
  # otherwise this step takes > 120 seconds and fails to install.
  # also skip this step if we're in CI/CD (github actions), because reasons.
  if [ -z "$CI" ]; then
    if [ -n "$SUPERVISOR_DOTFILE_REPO" ] || [ -n "$IS_DARWIN" ]; then
      which rvm >&/dev/null || command curl -fsSL https://get.rvm.io | bash -s stable --rails;

      # install some essentials
      brew install "${verbosity-}" --overwrite \
        gcc \
        cmake \
        make \
        bash \
        git \
        git-extras \
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
      2>/dev/null

      # for developing jekyll sites (and other things for github pages, etc)
      if which gem >&/dev/null; then
        gem install jekyll bundler jekyll-vite rouge
      fi

      # for macOS
      if [ -n "$IS_DARWIN" ]; then
        brew tap jeroenknoops/tap
        brew install "${verbosity-}" \
          gcc coreutils gitin gpg gpg-suite pinentry-mac python3

        export SHELL="${HOMEBREW_PREFIX:-}/bin/bash"
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
        brew install --overwrite gnupg gnupg2 xclip
      fi
    fi
  fi
}

function global_add() {
  local pkg pkgs agent i=1
  agent=$(which pnpm 2>/dev/null || which npm 2>/dev/null)
  pkgs=("$@")
  eval "$("$agent" add -g "$@" >&/dev/null)" && {
    echo "Successfully installed $# global packages!"
    for pkg in "${pkgs[@]}"; do
      echo " ${i-}. $pkg "
      ((i++))
    done
  }
}

# installs PNPM and Node.js (if needed) and some minimal global packages
function setup_node() {
  # shellcheck disable=SC2120
  local node_v
  node_v="${1:-lts}"

  # install pnpm if not already installed
  if ! which pnpm >&/dev/null; then
    curl -fsSL https://get.pnpm.io/install.sh | bash - 2>/dev/null
  fi

  # install node.js  if we don't have it yet
  if ! which node >&/dev/null || ! node -v >&/dev/null; then
    pnpm env use -g "${node_v:-lts}" 2>/dev/null || pnpm env use -g lts
  fi

  # global_add @antfu/ni degit @types/node typescript tslib tsm tsup ts-node eslint standard prettier prettier-plugin-sh svelte @sveltejs/kit@next tailwindcss postcss autoprefixer windicss sirv-cli microbundle

  global_add @antfu/ni @dotenv/cli vercel turbo wrangler@beta miniflare@latest cron-scheduler worktop@next 2>/dev/null
  unset -f global_add
}

# runs all the other scripts and cleans up after itself. geronimo!
function main() {
  function print_banner () {
    local message divider divider_length i
    case "${1-}" in
      (step)
        printf '\033[2m(%d / %d) \033[0;1m%s\033[0m' "$STEP_NUM" "$STEP_TOTAL" "${*:2}"
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
          clear && printf '\n\033[1m %s \033[0m\n\033[2m%s\033[0m\n' "${message-}" "${divider-}"
      ;;
    esac
  }

  function print_step_complete () {
    local delay=3
    if (($# > 0)); then
      printf '\n\033[1;3;42m\033[38;2;255;255;255m %s \033[0;2;3m %s\n\n' "${1-}" "${*:2}"
    else
      # pause for a moment and clear the screen
      sleep "${delay:-3}s" && clear
      # display the completed step number and total number of steps
      echo -e '\n\033[1;4m Completed step '$STEP_NUM' of '$STEP_TOTAL'.\033[0m\n\n'
      # increment step number by 1
      ((step++))
      # pause and clear again before proceeding to next step
      sleep "${delay:-3}s" && clear
    fi
  }

  print_banner "Beginning dotfiles installation. This may take a few minutes."
  printf ' \033[1;4m%s\033[0m: %s ' 'Working Dir' "$(curdir)"

  print_banner step $'Linking \033[1;4;33mdotfiles\033[0;1m to \033[1;3;4;36m/home/gitpod'
  setup_home >> ~/.dotfiles/.install.log \
    && print_step_complete

  print_banner step $'Installing/upgrading \033[1;4;31mPNPM\033[0;1m and \033[4;32mNode LTS\033[0;1;2m (latest)'
  setup_node >> ~/.dotfiles/.install.log \
    && print_step_complete

  print_banner step $'Installing/upgrading \033[1;4;35mhomebrew\033[0;1m and required formulae...'
  setup_brew >> ~/.dotfiles/.install.log \
    && print_step_complete

  print_step_complete 'COMPLETE!' 'Restarting shell environment...'
  sleep 4s && clear

  # shellcheck source=/dev/null
  source /home/gitpod/.bashrc 2>/dev/null || return $?
  return 0
}

function cleanup_env () {
  unset -v OSYS IS_DARWIN STEP_NUM STEP_TOTAL verbosity
  unset -f main setup_home setup_node setup_brew print_step_complete curdir
}

# run it and clean up after!
(main && cleanup_env && unset -f cleanup_env) || exit $?

# still here? throw codes bro
exit 1
