#!/usr/bin/env bash

OSYS="$(uname | tr '[:upper:]' '[:lower:]')"
[ "$OSYS" = "darwin" ] && export IS_DARWIN=1
[ -z "$CI" ] && verbosity="--quiet" || verbosity="--verbose"
[ -z "$TERM" ] && export TERM=xterm

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
  # install homebrew if not already installed
  if ! which brew >&/dev/null; then
    curl -fsSL https://raw.github.com/Homebrew/install/HEAD/install.sh | bash -
  fi

  # execute now just to be sure its available for us immediately
  eval "$(brew shellenv 2>/dev/null)"

  brew install "${verbosity-}" --overwrite starship gh

  # don't install when we're in a gitpod environment
  # otherwise this step takes > 120 seconds and fails to install.
  # also skip this step if we're in CI/CD (github actions), because reasons.
  if [ -z "$CI" ]; then
    if [ -n "$SUPERVISOR_DOTFILE_REPO" ] || [ -n "$IS_DARWIN" ]; then
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
        supabase/tap/supabase \
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
        sudo gem install jekyll builder jekyll-vite rouge
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
        brew install --overwrite gnupg gnupg2
      fi
    fi
  fi
}

function global_add() {
  local pkg pkgs
  pkgs=("$@")
  pnpm add -g "$@" >&/dev/null && {
    echo "Successfully installed $# global packages!"
    for pkg in "${pkgs[@]}"; do
      echo "  - $pkg"
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
  clear
  echo -e "\\n\\033[1mBeginning dotfiles install. This may take a while...\\033[0m"
  echo -e "-------------------------------------------------------\\n"
  echo "WORKDIR: $(curdir)"

  if [[ "$(uname -s)" == "Darwin" ]]; then
    export PATH="$HOME/Library/pnpm:/usr/local/bin:/usr/local/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
  else
    export PATH="$HOME/.local/share/pnpm:/usr/local/bin:/usr/local/sbin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
  fi

  echo -e '1. \033[1mLinking \033[1;4;33mdotfiles\033[0;1m to \033[1;3;4;36mHOMEDIR\033[0m...'
  setup_home && unset -f setup_home
  sleep 1 && clear && echo -e '\033[1;3;4mFinished step 1 of 3.\033[0m'

  echo -e '2. \033[1mInstalling \033[1;4;31mPNPM\033[0;1m and \033[1;4;32mNode.js\033[0;1;2m (latest LTS release)\033[0m'
  setup_node && unset -f setup_node
  sleep 1 && clear && echo -e '\033[1;3;4mFinished step 2 of 3.\033[0m'

  echo -e '3. \033[1mInstalling or updating \033[1;4;35mhomebrew\033[0;1m, and some of the bare-minimum tooling...\033[0m'
  setup_brew && unset -f setup_brew
  sleep 1 && clear && echo -e '\033[1;3;4mFinished step 3 of 3.\033[0m'
  sleep 2 && clear && echo -e '\033[1;3;4;42m\033[38;2;255;255;255m COMPLETE! \033[0m Restarting bash... happy coding!'
  sleep 2 && clear && unset -v OSYS IS_DARWIN curdir verbosity
  # shellcheck source=/dev/null
  source /home/gitpod/.bashrc 2>/dev/null || return $?
  return 0
}

# run it and clean up after!
main && unset -f main && exit 0

# still here? throw codes bro
exit $?
